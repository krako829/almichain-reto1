-- =====================================================================
-- Almi-Chain · Usuarios de MariaDB con mínimo privilegio
-- Las contraseñas NO van aquí: se pasan como variables al ejecutarlo
-- (README del bloque 07, apartado 4: se leen con "read -s" y van por la
-- entrada estándar, así no quedan en el historial ni se ven con "ps").
-- Se guardan en KeePassXC.
--
-- Si falta alguna variable, el script se para ANTES de tocar ningún usuario.
-- QUOTE() pone las comillas: una contraseña con ' no rompe la sentencia.
-- CREATE OR REPLACE USER: se puede ejecutar otra vez para cambiar las contraseñas.
-- =====================================================================

DELIMITER //
BEGIN NOT ATOMIC
  IF @p_app IS NULL OR @p_consulta IS NULL OR @p_copias IS NULL
     OR @p_app = '' OR @p_consulta = '' OR @p_copias = '' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Faltan contraseñas: define @p_app, @p_consulta y @p_copias antes de cargar 03-usuarios.sql';
  END IF;
END //
DELIMITER ;

-- Usuario de la aplicación: lee y escribe datos, no cambia la estructura
SET @s = CONCAT("CREATE OR REPLACE USER 'app_almichain'@'localhost' IDENTIFIED BY ", QUOTE(@p_app));
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
GRANT SELECT, INSERT, UPDATE, DELETE ON almichain.* TO 'app_almichain'@'localhost';

-- Usuario de consulta (gerencia, informes): solo lectura
SET @s = CONCAT("CREATE OR REPLACE USER 'consulta'@'localhost' IDENTIFIED BY ", QUOTE(@p_consulta));
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
GRANT SELECT, SHOW VIEW ON almichain.* TO 'consulta'@'localhost';

-- Usuario de copias: lo mínimo que necesita mariadb-dump, y solo sobre almichain
-- (con SELECT en *.* podría leer mysql.global_priv, donde están los hashes de todas las contraseñas)
SET @s = CONCAT("CREATE OR REPLACE USER 'copias'@'localhost' IDENTIFIED BY ", QUOTE(@p_copias));
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, EVENT ON almichain.* TO 'copias'@'localhost';
-- --routines lee los procedimientos de mysql.proc (MariaDB 10.11)
GRANT SELECT ON mysql.proc TO 'copias'@'localhost';

-- Nadie más necesita las variables: se borran
SET @p_app = NULL, @p_consulta = NULL, @p_copias = NULL, @s = NULL;

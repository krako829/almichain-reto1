-- =====================================================================
-- Almi-Chain · Usuarios de MariaDB con mínimo privilegio
-- Las contraseñas NO van aquí: se pasan como variables al ejecutar
--   sudo mariadb -e "SET @p_app='...'; SET @p_consulta='...'; SET @p_copias='...'; SOURCE 03-usuarios.sql;"
-- (y se guardan en KeePassXC)
-- =====================================================================

-- Usuario de la aplicación: lee y escribe datos, no cambia la estructura
DROP USER IF EXISTS 'app_almichain'@'localhost';
SET @s = CONCAT("CREATE USER 'app_almichain'@'localhost' IDENTIFIED BY '", @p_app, "'");
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
GRANT SELECT, INSERT, UPDATE, DELETE ON almichain.* TO 'app_almichain'@'localhost';

-- Usuario de consulta (gerencia, informes): solo lectura
DROP USER IF EXISTS 'consulta'@'localhost';
SET @s = CONCAT("CREATE USER 'consulta'@'localhost' IDENTIFIED BY '", @p_consulta, "'");
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
GRANT SELECT, SHOW VIEW ON almichain.* TO 'consulta'@'localhost';

-- Usuario de copias: lo mínimo que necesita mysqldump
DROP USER IF EXISTS 'copias'@'localhost';
SET @s = CONCAT("CREATE USER 'copias'@'localhost' IDENTIFIED BY '", @p_copias, "'");
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, EVENT ON *.* TO 'copias'@'localhost';

FLUSH PRIVILEGES;

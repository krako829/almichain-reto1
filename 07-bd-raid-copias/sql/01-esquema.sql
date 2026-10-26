-- =====================================================================
-- Almi-Chain · Base de datos de un local
-- Esquema según el diagrama del equipo (diagramas/modelo-er-equipo.pdf)
-- MariaDB 10.11 · motor InnoDB · utf8mb4
-- =====================================================================

DROP DATABASE IF EXISTS almichain;
CREATE DATABASE almichain CHARACTER SET utf8mb4 COLLATE utf8mb4_spanish_ci;
USE almichain;

-- ---------- Tablas sin claves ajenas ----------

CREATE TABLE cliente (
  id_cliente  INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(50)  NOT NULL,
  apellidos   VARCHAR(100) NOT NULL,
  telefono    VARCHAR(15),
  email       VARCHAR(100),
  CONSTRAINT uq_cliente_email UNIQUE (email)
) ENGINE=InnoDB;

CREATE TABLE mesa (
  id_mesa    INT AUTO_INCREMENT PRIMARY KEY,
  numero     INT NOT NULL,
  capacidad  INT NOT NULL,
  zona       VARCHAR(30),
  CONSTRAINT uq_mesa_numero UNIQUE (numero),
  CONSTRAINT ck_mesa_capacidad CHECK (capacidad BETWEEN 1 AND 20),
  CONSTRAINT ck_mesa_zona CHECK (zona IN ('sala', 'terraza', 'barra'))
) ENGINE=InnoDB;

CREATE TABLE empleado (
  id_empleado        INT AUTO_INCREMENT PRIMARY KEY,
  nombre             VARCHAR(50)  NOT NULL,
  apellidos          VARCHAR(100) NOT NULL,
  puesto             VARCHAR(30)  NOT NULL,
  telefono           VARCHAR(15),
  fecha_contratacion DATE,
  sueldo             DECIMAL(8,2),
  CONSTRAINT ck_empleado_sueldo CHECK (sueldo IS NULL OR sueldo > 0)
) ENGINE=InnoDB;

CREATE TABLE categoria (
  id_categoria INT AUTO_INCREMENT PRIMARY KEY,
  nombre       VARCHAR(50) NOT NULL,
  CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

CREATE TABLE ingrediente (
  id_ingrediente INT AUTO_INCREMENT PRIMARY KEY,
  nombre         VARCHAR(50) NOT NULL,
  stock          DECIMAL(8,2) DEFAULT 0,
  unidad_medida  VARCHAR(20),
  CONSTRAINT uq_ingrediente_nombre UNIQUE (nombre),
  CONSTRAINT ck_ingrediente_stock CHECK (stock >= 0)
) ENGINE=InnoDB;

CREATE TABLE proveedor (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL,
  telefono     VARCHAR(15),
  email        VARCHAR(100),
  direccion    VARCHAR(150)
) ENGINE=InnoDB;

-- ---------- Tablas con claves ajenas ----------

-- Un cliente hace 0..N reservas; cada reserva es de 1 cliente y 1 mesa
CREATE TABLE reserva (
  id_reserva    INT AUTO_INCREMENT PRIMARY KEY,
  fecha         DATE NOT NULL,
  hora          TIME NOT NULL,
  num_personas  INT  NOT NULL,
  id_cliente    INT  NOT NULL,
  id_mesa       INT  NOT NULL,
  CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reserva_mesa FOREIGN KEY (id_mesa) REFERENCES mesa (id_mesa)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  -- una mesa no se reserva dos veces a la misma hora
  CONSTRAINT uq_reserva_mesa_hora UNIQUE (id_mesa, fecha, hora),
  CONSTRAINT ck_reserva_personas CHECK (num_personas BETWEEN 1 AND 20)
) ENGINE=InnoDB;

CREATE TABLE plato (
  id_plato     INT AUTO_INCREMENT PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL,
  descripcion  TEXT,
  precio       DECIMAL(6,2) NOT NULL,
  id_categoria INT NOT NULL,
  CONSTRAINT fk_plato_categoria FOREIGN KEY (id_categoria) REFERENCES categoria (id_categoria)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT uq_plato_nombre UNIQUE (nombre),
  CONSTRAINT ck_plato_precio CHECK (precio > 0)
) ENGINE=InnoDB;

-- La comanda la toma 1 empleado en 1 mesa; el cliente es opcional (0..1)
CREATE TABLE comanda (
  id_comanda   INT AUTO_INCREMENT PRIMARY KEY,
  fecha_hora   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado       VARCHAR(20) NOT NULL DEFAULT 'abierta',
  id_mesa      INT NOT NULL,
  id_empleado  INT NOT NULL,
  id_cliente   INT NULL,
  CONSTRAINT fk_comanda_mesa FOREIGN KEY (id_mesa) REFERENCES mesa (id_mesa)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_comanda_empleado FOREIGN KEY (id_empleado) REFERENCES empleado (id_empleado)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_comanda_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT ck_comanda_estado CHECK (estado IN ('abierta', 'servida', 'pagada', 'anulada'))
) ENGINE=InnoDB;

-- N:M comanda-plato. Se guarda el precio del momento de la venta
CREATE TABLE detalle_comanda (
  id_comanda       INT NOT NULL,
  id_plato         INT NOT NULL,
  cantidad         INT NOT NULL,
  precio_unitario  DECIMAL(6,2) NOT NULL,
  PRIMARY KEY (id_comanda, id_plato),
  CONSTRAINT fk_detalle_comanda FOREIGN KEY (id_comanda) REFERENCES comanda (id_comanda)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_detalle_plato FOREIGN KEY (id_plato) REFERENCES plato (id_plato)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_detalle_precio CHECK (precio_unitario >= 0)
) ENGINE=InnoDB;

-- N:M plato-ingrediente (la receta)
CREATE TABLE plato_ingrediente (
  id_plato           INT NOT NULL,
  id_ingrediente     INT NOT NULL,
  cantidad_necesaria DECIMAL(8,2) NOT NULL,
  PRIMARY KEY (id_plato, id_ingrediente),
  CONSTRAINT fk_receta_plato FOREIGN KEY (id_plato) REFERENCES plato (id_plato)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_receta_ingrediente FOREIGN KEY (id_ingrediente) REFERENCES ingrediente (id_ingrediente)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_receta_cantidad CHECK (cantidad_necesaria > 0)
) ENGINE=InnoDB;

-- N:M proveedor-ingrediente, con el precio de compra de cada proveedor
CREATE TABLE suministro (
  id_proveedor   INT NOT NULL,
  id_ingrediente INT NOT NULL,
  precio_compra  DECIMAL(8,2),
  PRIMARY KEY (id_proveedor, id_ingrediente),
  CONSTRAINT fk_suministro_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedor (id_proveedor)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_suministro_ingrediente FOREIGN KEY (id_ingrediente) REFERENCES ingrediente (id_ingrediente)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_suministro_precio CHECK (precio_compra IS NULL OR precio_compra > 0)
) ENGINE=InnoDB;

-- 1:1 comanda-factura (UNIQUE en id_comanda)
CREATE TABLE factura (
  id_factura   INT AUTO_INCREMENT PRIMARY KEY,
  fecha        DATE NOT NULL,
  total        DECIMAL(8,2) NOT NULL,
  metodo_pago  VARCHAR(20)  NOT NULL,
  id_comanda   INT NOT NULL,
  CONSTRAINT uq_factura_comanda UNIQUE (id_comanda),
  CONSTRAINT fk_factura_comanda FOREIGN KEY (id_comanda) REFERENCES comanda (id_comanda)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_factura_metodo CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'bizum')),
  CONSTRAINT ck_factura_total CHECK (total >= 0)
) ENGINE=InnoDB;

-- ---------- Índices para las consultas más habituales ----------
CREATE INDEX ix_comanda_fecha  ON comanda (fecha_hora);
CREATE INDEX ix_reserva_fecha  ON reserva (fecha, hora);
CREATE INDEX ix_factura_fecha  ON factura (fecha);

-- ---------- Vista: importe de cada comanda ----------
CREATE VIEW v_importe_comanda AS
SELECT c.id_comanda,
       c.fecha_hora,
       m.numero                              AS mesa,
       CONCAT(e.nombre, ' ', e.apellidos)    AS camarero,
       c.estado,
       SUM(d.cantidad * d.precio_unitario)   AS importe
FROM comanda c
JOIN mesa m             ON m.id_mesa = c.id_mesa
JOIN empleado e         ON e.id_empleado = c.id_empleado
JOIN detalle_comanda d  ON d.id_comanda = c.id_comanda
GROUP BY c.id_comanda, c.fecha_hora, m.numero, camarero, c.estado;

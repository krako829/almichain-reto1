-- =====================================================================
-- Almi-Chain · Datos de ejemplo (ficticios)
-- =====================================================================
USE almichain;

INSERT INTO cliente (nombre, apellidos, telefono, email) VALUES
 ('Ane',     'Etxeberria Goikoetxea', '600111222', 'ane.etxe@example.com'),
 ('Jon',     'Arrieta Uriarte',       '600222333', 'jon.arrieta@example.com'),
 ('Lucía',   'Martín Gómez',          '600333444', 'lucia.martin@example.com'),
 ('Iker',    'Zubizarreta Lasa',      '600444555', 'iker.zubi@example.com'),
 ('Marta',   'Pérez Ruiz',            '600555666', 'marta.perez@example.com'),
 ('Unai',    'Garai Bilbao',          '600666777', NULL);

INSERT INTO mesa (numero, capacidad, zona) VALUES
 (1, 2, 'sala'), (2, 4, 'sala'), (3, 4, 'sala'), (4, 6, 'sala'),
 (5, 2, 'terraza'), (6, 4, 'terraza'), (7, 8, 'terraza'),
 (8, 1, 'barra'), (9, 1, 'barra');

INSERT INTO empleado (nombre, apellidos, puesto, telefono, fecha_contratacion, sueldo) VALUES
 ('Gorka',  'Larrea Ibarra',   'gerente',  '611000001', '2022-03-01', 2400.00),
 ('Nerea',  'Olabarria Sanz',  'camarera', '611000002', '2023-06-15', 1450.00),
 ('Asier',  'Landa Mendieta',  'camarero', '611000003', '2024-01-10', 1450.00),
 ('Miren',  'Agirre Elorza',   'cocinera', '611000004', '2021-09-20', 1750.00),
 ('Pablo',  'Sánchez Vidal',   'ayudante de cocina', '611000005', '2025-02-01', 1300.00);

INSERT INTO categoria (nombre) VALUES
 ('Bebidas'), ('Entrantes'), ('Principales'), ('Postres');

INSERT INTO plato (nombre, descripcion, precio, id_categoria) VALUES
 ('Agua mineral 50 cl',     'Botella de agua sin gas',                1.80, 1),
 ('Refresco de cola',       'Lata 33 cl',                             2.50, 1),
 ('Caña de cerveza',        'Cerveza de barril 20 cl',                2.20, 1),
 ('Café con leche',         'Café espresso con leche',                1.70, 1),
 ('Croquetas caseras (6)',  'Croquetas de jamón',                     7.50, 2),
 ('Ensalada de la casa',    'Lechuga, tomate, cebolla y bonito',      8.90, 2),
 ('Hamburguesa Almi',       'Ternera, queso, lechuga y patatas',     12.50, 3),
 ('Bacalao al pil-pil',     'Bacalao con salsa pil-pil',             16.90, 3),
 ('Pasta boloñesa',         'Espaguetis con salsa boloñesa',         10.50, 3),
 ('Tarta de queso',         'Tarta de queso casera',                  5.20, 4),
 ('Goxua',                  'Postre típico vasco',                    5.50, 4);

INSERT INTO ingrediente (nombre, stock, unidad_medida) VALUES
 ('Carne de ternera picada', 12.00, 'kg'),
 ('Pan de hamburguesa',      80.00, 'unidad'),
 ('Queso en lonchas',         4.50, 'kg'),
 ('Lechuga',                 25.00, 'unidad'),
 ('Tomate',                  18.00, 'kg'),
 ('Bacalao desalado',         9.00, 'kg'),
 ('Aceite de oliva',         30.00, 'l'),
 ('Ajo',                      2.00, 'kg'),
 ('Espaguetis',              15.00, 'kg'),
 ('Patatas',                 40.00, 'kg'),
 ('Queso crema',              6.00, 'kg'),
 ('Huevos',                 180.00, 'unidad'),
 ('Nata',                    10.00, 'l'),
 ('Jamón serrano',            3.50, 'kg'),
 ('Leche',                   24.00, 'l');

-- Recetas (cantidad por ración)
INSERT INTO plato_ingrediente (id_plato, id_ingrediente, cantidad_necesaria) VALUES
 (7, 1, 0.18), (7, 2, 1), (7, 3, 0.03), (7, 4, 0.10), (7, 10, 0.25),
 (8, 6, 0.25), (8, 7, 0.10), (8, 8, 0.02),
 (9, 9, 0.12), (9, 1, 0.10), (9, 5, 0.15),
 (6, 4, 0.25), (6, 5, 0.15), (6, 7, 0.02),
 (5, 14, 0.06), (5, 15, 0.15), (5, 12, 1),
 (10, 11, 0.12), (10, 12, 1), (10, 13, 0.05),
 (11, 12, 2), (11, 13, 0.08), (11, 15, 0.10);

INSERT INTO proveedor (nombre, telefono, email, direccion) VALUES
 ('Carnes Bizkaia S.L.',      '944000001', 'pedidos@carnesbizkaia.example', 'Polígono Ugaldeguren, Zamudio'),
 ('Pescados del Cantábrico',  '944000002', 'ventas@pescadoscant.example',   'Muelle de Santurtzi'),
 ('Huerta de Gernika',        '944000003', 'info@huertagernika.example',    'Barrio Lumo, Gernika'),
 ('Distribuciones Bilbao',    '944000004', 'comercial@distbilbao.example',  'Calle Iturribide 12, Bilbao');

INSERT INTO suministro (id_proveedor, id_ingrediente, precio_compra) VALUES
 (1, 1, 9.80), (1, 14, 21.50), (1, 3, 8.40),
 (2, 6, 18.90),
 (3, 4, 0.85), (3, 5, 2.10), (3, 10, 0.90), (3, 8, 4.20),
 (4, 2, 0.35), (4, 7, 6.90), (4, 9, 1.60), (4, 11, 7.80), (4, 12, 0.22), (4, 13, 3.40), (4, 15, 0.95),
 (1, 12, 0.24);

INSERT INTO reserva (fecha, hora, num_personas, id_cliente, id_mesa) VALUES
 ('2026-10-24', '14:00', 4, 1, 2),
 ('2026-10-24', '14:30', 2, 2, 1),
 ('2026-10-24', '21:00', 6, 3, 4),
 ('2026-10-25', '14:00', 4, 4, 6),
 ('2026-10-25', '21:30', 2, 5, 5),
 ('2026-10-31', '21:00', 8, 1, 7);

INSERT INTO comanda (fecha_hora, estado, id_mesa, id_empleado, id_cliente) VALUES
 ('2026-10-24 14:05', 'pagada',  2, 2, 1),
 ('2026-10-24 14:35', 'pagada',  1, 3, 2),
 ('2026-10-24 21:10', 'pagada',  4, 2, 3),
 ('2026-10-25 09:15', 'pagada',  8, 3, NULL),
 ('2026-10-25 14:10', 'pagada',  6, 2, 4),
 ('2026-10-25 21:40', 'servida', 5, 3, 5),
 ('2026-10-26 10:00', 'abierta', 9, 2, NULL);

INSERT INTO detalle_comanda (id_comanda, id_plato, cantidad, precio_unitario) VALUES
 (1, 3, 2, 2.20), (1, 5, 1, 7.50), (1, 7, 2, 12.50), (1, 10, 2, 5.20),
 (2, 1, 2, 1.80), (2, 8, 2, 16.90), (2, 11, 1, 5.50),
 (3, 2, 3, 2.50), (3, 3, 3, 2.20), (3, 6, 2, 8.90), (3, 9, 3, 10.50), (3, 7, 3, 12.50),
 (4, 4, 1, 1.70),
 (5, 3, 4, 2.20), (5, 5, 2, 7.50), (5, 8, 2, 16.90), (5, 7, 2, 12.50), (5, 10, 4, 5.20),
 (6, 1, 1, 1.80), (6, 9, 2, 10.50),
 (7, 4, 2, 1.70);

INSERT INTO factura (fecha, total, metodo_pago, id_comanda)
SELECT DATE(v.fecha_hora), v.importe,
       CASE v.id_comanda WHEN 2 THEN 'efectivo' WHEN 4 THEN 'efectivo' ELSE 'tarjeta' END,
       v.id_comanda
FROM v_importe_comanda v
WHERE v.estado = 'pagada';

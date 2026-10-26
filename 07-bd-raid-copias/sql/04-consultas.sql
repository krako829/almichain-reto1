-- =====================================================================
-- Almi-Chain · Consultas de prueba (resultado en capturas/)
-- =====================================================================
USE almichain;

-- C1. Carta completa ordenada por categoría y precio
SELECT c.nombre AS categoria, p.nombre AS plato, p.precio
FROM plato p JOIN categoria c ON c.id_categoria = p.id_categoria
ORDER BY c.id_categoria, p.precio;

-- C2. Reservas de un día con el nombre del cliente y la zona de la mesa
SELECT r.hora, CONCAT(cl.nombre, ' ', cl.apellidos) AS cliente,
       r.num_personas, m.numero AS mesa, m.zona
FROM reserva r
JOIN cliente cl ON cl.id_cliente = r.id_cliente
JOIN mesa m     ON m.id_mesa = r.id_mesa
WHERE r.fecha = '2026-10-24'
ORDER BY r.hora;

-- C3. Importe de cada comanda (vista)
SELECT * FROM v_importe_comanda ORDER BY id_comanda;

-- C4. Facturación por día y método de pago
SELECT fecha, metodo_pago, COUNT(*) AS facturas, SUM(total) AS total
FROM factura
GROUP BY fecha, metodo_pago WITH ROLLUP;

-- C5. Los 5 platos más vendidos (unidades e ingresos)
SELECT p.nombre, SUM(d.cantidad) AS unidades,
       SUM(d.cantidad * d.precio_unitario) AS ingresos
FROM detalle_comanda d JOIN plato p ON p.id_plato = d.id_plato
GROUP BY p.id_plato, p.nombre
ORDER BY unidades DESC
LIMIT 5;

-- C6. Ventas por camarero
SELECT CONCAT(e.nombre, ' ', e.apellidos) AS camarero,
       COUNT(DISTINCT v.id_comanda) AS comandas, SUM(v.importe) AS vendido
FROM v_importe_comanda v
JOIN comanda c  ON c.id_comanda = v.id_comanda
JOIN empleado e ON e.id_empleado = c.id_empleado
GROUP BY e.id_empleado
ORDER BY vendido DESC;

-- C7. Receta y coste de la hamburguesa con el proveedor más barato
SELECT i.nombre AS ingrediente, pi.cantidad_necesaria, i.unidad_medida,
       MIN(s.precio_compra) AS mejor_precio,
       ROUND(pi.cantidad_necesaria * MIN(s.precio_compra), 2) AS coste
FROM plato_ingrediente pi
JOIN ingrediente i ON i.id_ingrediente = pi.id_ingrediente
LEFT JOIN suministro s ON s.id_ingrediente = i.id_ingrediente
WHERE pi.id_plato = (SELECT id_plato FROM plato WHERE nombre = 'Hamburguesa Almi')
GROUP BY i.id_ingrediente, i.nombre, pi.cantidad_necesaria, i.unidad_medida;

-- C8. Ingredientes con poco stock y quién los sirve
SELECT i.nombre, i.stock, i.unidad_medida,
       GROUP_CONCAT(pr.nombre ORDER BY s.precio_compra SEPARATOR ', ') AS proveedores
FROM ingrediente i
LEFT JOIN suministro s ON s.id_ingrediente = i.id_ingrediente
LEFT JOIN proveedor pr ON pr.id_proveedor = s.id_proveedor
WHERE i.stock < 5
GROUP BY i.id_ingrediente;

-- C9. Comandas sin cobrar todavía (sin factura)
SELECT c.id_comanda, c.fecha_hora, c.estado, m.numero AS mesa
FROM comanda c
JOIN mesa m ON m.id_mesa = c.id_mesa
LEFT JOIN factura f ON f.id_comanda = c.id_comanda
WHERE f.id_factura IS NULL;

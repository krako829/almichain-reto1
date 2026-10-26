-- Almi-Chain · Recuento de filas de cada tabla (para comparar antes y después de restaurar)
USE almichain;
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'comanda', COUNT(*) FROM comanda
UNION ALL SELECT 'detalle_comanda', COUNT(*) FROM detalle_comanda
UNION ALL SELECT 'empleado', COUNT(*) FROM empleado
UNION ALL SELECT 'factura', COUNT(*) FROM factura
UNION ALL SELECT 'ingrediente', COUNT(*) FROM ingrediente
UNION ALL SELECT 'mesa', COUNT(*) FROM mesa
UNION ALL SELECT 'plato', COUNT(*) FROM plato
UNION ALL SELECT 'plato_ingrediente', COUNT(*) FROM plato_ingrediente
UNION ALL SELECT 'proveedor', COUNT(*) FROM proveedor
UNION ALL SELECT 'reserva', COUNT(*) FROM reserva
UNION ALL SELECT 'suministro', COUNT(*) FROM suministro;
SELECT ROUND(SUM(total), 2) AS total_facturado FROM factura;

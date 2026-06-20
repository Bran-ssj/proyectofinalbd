-- Consulta 1: Mostrar libros con su categoría y editorial
SELECT
    l.id_libro,
    UPPER(l.titulo) AS titulo,
    c.nombre AS categoria,
    e.nombre AS editorial
FROM libro l
INNER JOIN categoria c
    ON l.id_categoria = c.id_categoria
INNER JOIN editorial e
    ON l.id_editorial = e.id_editorial;

-- Consulta 2: Mostrar libros y autores
SELECT
    UPPER(l.titulo) AS titulo, 
    a.nombre AS autor
FROM libro l
INNER JOIN libro_autor la
    ON l.id_libro = la.id_libro
INNER JOIN autor a
    ON la.id_autor = a.id_autor;

-- Consulta 3: Mostrar ejemplares disponibles
SELECT
    id_ejemplar,
    numero_ejemplar,
    estado,
    ubicacion
FROM ejemplar
WHERE estado = 'Disponible';

-- Consulta 4: Mostrar devoluciones realizadas
SELECT
    d.id_devolucion,
    UPPER(s.nombre) AS socio,        
    l.titulo,
    d.fecha_devolucion
FROM devolucion d
INNER JOIN prestamo p
    ON d.id_prestamo = p.id_prestamo
INNER JOIN socio s
    ON p.id_socio = s.id_socio
INNER JOIN ejemplar ej
    ON p.id_ejemplar = ej.id_ejemplar
INNER JOIN libro l
    ON ej.id_libro = l.id_libro;

-- Consulta 5: Mostrar multas
SELECT
    m.id_multa,
    m.monto,
    m.pagada,
    s.nombre AS socio
FROM multa m
INNER JOIN devolucion d
    ON m.id_devolucion = d.id_devolucion
INNER JOIN prestamo p
    ON d.id_prestamo = p.id_prestamo
INNER JOIN socio s
    ON p.id_socio = s.id_socio;

-- CONSULTA 6: Libros más prestados en los últimos 3 meses
SELECT
    l.titulo,
    COUNT(*) AS veces_prestado
FROM prestamo p
INNER JOIN ejemplar e
    ON p.id_ejemplar = e.id_ejemplar
INNER JOIN libro l
    ON e.id_libro = l.id_libro
WHERE p.fecha_prestamo >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY l.titulo
ORDER BY veces_prestado DESC;

-- CONSULTA 7: Socios con multas pendientes
SELECT
    UPPER(s.nombre) AS socio,         
    LOWER(s.correo) AS correo,        
    m.monto
FROM multa m
INNER JOIN devolucion d
    ON m.id_devolucion = d.id_devolucion
INNER JOIN prestamo p
    ON d.id_prestamo = p.id_prestamo
INNER JOIN socio s
    ON p.id_socio = s.id_socio
WHERE m.pagada = FALSE;

-- CONSULTA 8: Autores con mayor número de títulos en catálogo
SELECT
    a.nombre AS autor,
    COUNT(*) AS titulos_en_catalogo
FROM autor a
INNER JOIN libro_autor la
    ON a.id_autor = la.id_autor
GROUP BY a.nombre
ORDER BY titulos_en_catalogo DESC;

-- CONSULTA 9: Ejemplares que nunca han sido prestados
SELECT
    e.id_ejemplar,
    l.titulo
FROM ejemplar e
INNER JOIN libro l
    ON e.id_libro = l.id_libro
WHERE e.id_ejemplar NOT IN
(
    SELECT id_ejemplar
    FROM prestamo
);

-- CONSULTA 10: Empleado que ha procesado más préstamos en el último mes
SELECT
    emp.nombre AS empleado,
    COUNT(*) AS prestamos_procesados_mes
FROM prestamo p
INNER JOIN empleado emp
    ON p.id_empleado = emp.id_empleado
WHERE DATE_TRUNC('month', p.fecha_prestamo) =
      (SELECT DATE_TRUNC('month', MAX(fecha_prestamo)) FROM prestamo)
GROUP BY emp.nombre
ORDER BY prestamos_procesados_mes DESC;
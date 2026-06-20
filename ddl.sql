-- ============================================================
-- BASE DE DATOS: BIBLIOTECA PUBLICA
-- Sistema para la gestión de libros, préstamos, reservas,
-- devoluciones, multas y usuarios de una biblioteca.
-- ============================================================

CREATE DATABASE biblio;

-- ============================================================
-- TABLA AUTOR
-- Almacena la información de los autores registrados en el
-- catálogo de la biblioteca.
-- ============================================================

CREATE TABLE autor (
    id_autor SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

-- ============================================================
-- TABLA CATEGORIA
-- Contiene las categorías o géneros a los que pertenecen
-- los libros del catálogo.
-- ============================================================

CREATE TABLE categoria (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

-- ============================================================
-- TABLA EDITORIAL
-- Registra las editoriales responsables de la publicación
-- de los libros disponibles en la biblioteca.
-- ============================================================

CREATE TABLE editorial (
    id_editorial SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

-- ============================================================
-- TABLA SOCIO
-- Almacena los datos de los usuarios registrados que pueden
-- realizar préstamos y reservas de ejemplares.
-- ============================================================

CREATE TABLE socio (
    id_socio SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(15) NOT NULL,
    correo VARCHAR(100) NOT NULL UNIQUE
);

-- ============================================================
-- TABLA EMPLEADO
-- Guarda la información del personal encargado de gestionar
-- los préstamos y demás operaciones de la biblioteca.
-- ============================================================

CREATE TABLE empleado (
    id_empleado SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    cargo VARCHAR(50) NOT NULL
);

-- ============================================================
-- TABLA LIBRO
-- Representa cada título disponible en el catálogo.
-- Cada libro pertenece a una categoría y es publicado por
-- una editorial.
-- ============================================================

CREATE TABLE libro (
    id_libro SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    anio_publicacion INTEGER NOT NULL
        CHECK (anio_publicacion >= 1000),
    id_categoria INTEGER NOT NULL,
    id_editorial INTEGER NOT NULL,

    CONSTRAINT fk_libro_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria),

    CONSTRAINT fk_libro_editorial
        FOREIGN KEY (id_editorial)
        REFERENCES editorial(id_editorial)
);

-- ============================================================
-- TABLA LIBRO_AUTOR
-- Tabla intermedia que implementa la relación muchos a muchos
-- entre libros y autores. Un libro puede tener varios autores
-- y un autor puede participar en varios libros.
-- ============================================================

CREATE TABLE libro_autor (
    id_libro INTEGER,
    id_autor INTEGER,

    PRIMARY KEY (id_libro, id_autor),

    CONSTRAINT fk_libroautor_libro
        FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro),

    CONSTRAINT fk_libroautor_autor
        FOREIGN KEY (id_autor)
        REFERENCES autor(id_autor)
);

-- ============================================================
-- TABLA EJEMPLAR
-- Registra las copias físicas de cada libro disponibles
-- dentro de la biblioteca.
-- ============================================================

CREATE TABLE ejemplar (
    id_ejemplar SERIAL PRIMARY KEY,
    numero_ejemplar INTEGER NOT NULL,
    estado VARCHAR(20) NOT NULL,
    ubicacion VARCHAR(50) NOT NULL,
    id_libro INTEGER NOT NULL,

    CONSTRAINT fk_ejemplar_libro
        FOREIGN KEY (id_libro)
        REFERENCES libro(id_libro)
);

-- ============================================================
-- TABLA PRESTAMO
-- Almacena los préstamos realizados por los socios.
-- Registra fechas, ejemplar prestado y empleado responsable.
-- ============================================================

CREATE TABLE prestamo (
    id_prestamo SERIAL PRIMARY KEY,
    fecha_prestamo DATE NOT NULL,
    fecha_limite DATE NOT NULL,
    id_socio INTEGER NOT NULL,
    id_ejemplar INTEGER NOT NULL,
    id_empleado INTEGER NOT NULL,

    CONSTRAINT fk_prestamo_socio
        FOREIGN KEY (id_socio)
        REFERENCES socio(id_socio),

    CONSTRAINT fk_prestamo_ejemplar
        FOREIGN KEY (id_ejemplar)
        REFERENCES ejemplar(id_ejemplar),

    CONSTRAINT fk_prestamo_empleado
        FOREIGN KEY (id_empleado)
        REFERENCES empleado(id_empleado),

    CONSTRAINT chk_prestamo_fechas
        CHECK (fecha_limite >= fecha_prestamo)
);

-- ============================================================
-- TABLA RESERVA
-- Registra las reservas realizadas por los socios sobre
-- ejemplares que no se encuentran disponibles (estan en préstamo).
-- ============================================================

CREATE TABLE reserva (
    id_reserva SERIAL PRIMARY KEY,
    fecha_reserva DATE NOT NULL,
    id_socio INTEGER NOT NULL,
    id_ejemplar INTEGER NOT NULL,

    CONSTRAINT fk_reserva_socio
        FOREIGN KEY (id_socio)
        REFERENCES socio(id_socio),

    CONSTRAINT fk_reserva_ejemplar
        FOREIGN KEY (id_ejemplar)
        REFERENCES ejemplar(id_ejemplar)
);

-- ============================================================
-- TABLA DEVOLUCION
-- Almacena la devolución de los préstamos realizados.
-- Cada préstamo puede generar una única devolución.
-- ============================================================

CREATE TABLE devolucion (
    id_devolucion SERIAL PRIMARY KEY,
    fecha_devolucion DATE NOT NULL,
    id_prestamo INTEGER UNIQUE NOT NULL,

    CONSTRAINT fk_devolucion_prestamo
        FOREIGN KEY (id_prestamo)
        REFERENCES prestamo(id_prestamo)
);

-- ============================================================
-- TABLA MULTA
-- Registra las multas generadas por devoluciones tardías.
-- Cada devolución puede generar como máximo una multa.
-- ============================================================

CREATE TABLE multa (
    id_multa SERIAL PRIMARY KEY,
    monto DECIMAL(10,2) NOT NULL,
    pagada BOOLEAN DEFAULT FALSE,
    id_devolucion INTEGER UNIQUE NOT NULL,

    CONSTRAINT fk_multa_devolucion
        FOREIGN KEY (id_devolucion)
        REFERENCES devolucion(id_devolucion),

    CONSTRAINT chk_multa_monto
        CHECK (monto >= 0)
);

-- ============================================================
-- PROGRAMACIÓN EN LA BASE DE DATOS (VERSIÓN CORREGIDA FINAL)
-- ============================================================


-- =====================================
-- FUNCION 1
-- Cantidad de prestamos de un socio
-- =====================================

CREATE OR REPLACE FUNCTION obtener_prestamos_socio(
    p_id_socio INTEGER
)
RETURNS INTEGER
AS $$
DECLARE
    total INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO total
    FROM prestamo
    WHERE id_socio = p_id_socio;

    RETURN total;

END;
$$ LANGUAGE plpgsql;


-- =====================================
-- FUNCION 2
-- Total acumulado de multas
-- =====================================

CREATE OR REPLACE FUNCTION total_multas()
RETURNS NUMERIC
AS $$
DECLARE
    total NUMERIC;
BEGIN

    SELECT COALESCE(SUM(monto),0)
    INTO total
    FROM multa;

    RETURN total;

END;
$$ LANGUAGE plpgsql;


-- =====================================
-- FUNCION 3
-- Verificar multas pendientes de un socio
-- =====================================

CREATE OR REPLACE FUNCTION tiene_multas_pendientes(
    p_id_socio INTEGER
)
RETURNS BOOLEAN
AS $$
DECLARE
    v_total INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_total
    FROM multa m
    INNER JOIN devolucion d
        ON m.id_devolucion = d.id_devolucion
    INNER JOIN prestamo p
        ON d.id_prestamo = p.id_prestamo
    WHERE p.id_socio = p_id_socio
      AND m.pagada = FALSE;

    RETURN v_total > 0;

END;
$$ LANGUAGE plpgsql;


-- =====================================
-- PROCEDIMIENTO 1
-- Registrar prestamo
-- =====================================

CREATE OR REPLACE PROCEDURE registrar_prestamo(
    p_fecha DATE,
    p_fecha_limite DATE,
    p_id_socio INTEGER,
    p_id_ejemplar INTEGER,
    p_id_empleado INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE

    v_estado VARCHAR(20);
    v_prestamos_activos INTEGER;
    v_multas INTEGER;

BEGIN

    -- Verificar disponibilidad

    SELECT estado
    INTO v_estado
    FROM ejemplar
    WHERE id_ejemplar = p_id_ejemplar;

    IF v_estado <> 'Disponible' THEN
        RAISE EXCEPTION
        'El ejemplar no está disponible';
    END IF;

    -- Verificar máximo 3 préstamos ACTIVOS (sin devolución registrada)

    SELECT COUNT(*)
    INTO v_prestamos_activos
    FROM prestamo p
    WHERE p.id_socio = p_id_socio
      AND NOT EXISTS (
            SELECT 1 FROM devolucion d WHERE d.id_prestamo = p.id_prestamo
      );

    IF v_prestamos_activos >= 3 THEN
        RAISE EXCEPTION
        'El socio ya posee 3 préstamos activos';
    END IF;

    -- Verificar multas pendientes DEL SOCIO

    SELECT COUNT(*)
    INTO v_multas
    FROM multa m
    INNER JOIN devolucion d
        ON m.id_devolucion = d.id_devolucion
    INNER JOIN prestamo p
        ON d.id_prestamo = p.id_prestamo
    WHERE p.id_socio = p_id_socio
      AND m.pagada = FALSE;

    IF v_multas > 0 THEN
        RAISE EXCEPTION
        'El socio tiene multas pendientes';
    END IF;

    INSERT INTO prestamo(
        fecha_prestamo,
        fecha_limite,
        id_socio,
        id_ejemplar,
        id_empleado
    )
    VALUES(
        p_fecha,
        p_fecha_limite,
        p_id_socio,
        p_id_ejemplar,
        p_id_empleado
    );

END;
$$;


-- =====================================
-- PROCEDIMIENTO 2
-- Registrar reserva
-- Corregido: la reserva se hace sobre un EJEMPLAR (que debe estar
-- en préstamo), no sobre un préstamo directamente, conforme al
-- modelo ER y relacional ya validados (RESERVA -> EJEMPLAR).
-- =====================================

CREATE OR REPLACE PROCEDURE registrar_reserva(
    p_fecha DATE,
    p_id_socio INTEGER,
    p_id_ejemplar INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR(20);
BEGIN

    -- Regla de negocio: un ejemplar solo puede reservarse si está prestado
    SELECT estado
    INTO v_estado
    FROM ejemplar
    WHERE id_ejemplar = p_id_ejemplar;

    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'El ejemplar indicado no existe';
    END IF;

    IF v_estado <> 'Prestado' THEN
        RAISE EXCEPTION
        'Solo se pueden reservar ejemplares que estén en préstamo';
    END IF;

    INSERT INTO reserva(
        fecha_reserva,
        id_socio,
        id_ejemplar
    )
    VALUES(
        p_fecha,
        p_id_socio,
        p_id_ejemplar
    );

END;
$$;


-- =====================================
-- PROCEDIMIENTO 3
-- Registrar pago de multa
-- =====================================

CREATE OR REPLACE PROCEDURE pagar_multa(
    p_id_multa INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE multa
    SET pagada = TRUE
    WHERE id_multa = p_id_multa;

END;
$$;


-- =====================================
-- TRIGGER 1
-- Cambiar estado a Prestado
-- =====================================

CREATE OR REPLACE FUNCTION actualizar_estado_prestamo()
RETURNS TRIGGER
AS $$
BEGIN

    UPDATE ejemplar
    SET estado = 'Prestado'
    WHERE id_ejemplar = NEW.id_ejemplar;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prestamo
AFTER INSERT ON prestamo
FOR EACH ROW
EXECUTE FUNCTION actualizar_estado_prestamo();


-- =====================================
-- TRIGGER 2
-- Cambiar estado a Disponible
-- =====================================

CREATE OR REPLACE FUNCTION actualizar_estado_devolucion()
RETURNS TRIGGER
AS $$
DECLARE
    v_ejemplar INTEGER;
BEGIN

    SELECT id_ejemplar
    INTO v_ejemplar
    FROM prestamo
    WHERE id_prestamo = NEW.id_prestamo;

    UPDATE ejemplar
    SET estado = 'Disponible'
    WHERE id_ejemplar = v_ejemplar;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_devolucion
AFTER INSERT ON devolucion
FOR EACH ROW
EXECUTE FUNCTION actualizar_estado_devolucion();


-- =====================================
-- TRIGGER 3
-- Generar multa automática
-- =====================================

CREATE OR REPLACE FUNCTION generar_multa_automatica()
RETURNS TRIGGER
AS $$
DECLARE

    v_fecha_limite DATE;
    v_dias_retraso INTEGER;
    v_monto NUMERIC(10,2);

BEGIN

    SELECT fecha_limite
    INTO v_fecha_limite
    FROM prestamo
    WHERE id_prestamo = NEW.id_prestamo;

    IF NEW.fecha_devolucion > v_fecha_limite THEN

        v_dias_retraso :=
            NEW.fecha_devolucion - v_fecha_limite;

        v_monto := v_dias_retraso * 1.00;

        INSERT INTO multa(
            monto,
            pagada,
            id_devolucion
        )
        VALUES(
            v_monto,
            FALSE,
            NEW.id_devolucion
        );

    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generar_multa
AFTER INSERT ON devolucion
FOR EACH ROW
EXECUTE FUNCTION generar_multa_automatica();


-- ============================================================
-- DEMOSTRACIÓN DE FUNCIONAMIENTO
-- ============================================================

-- ---- DEMO 1: registrar_prestamo + trg_prestamo ----
DO $$
DECLARE
    v_id_socio     INTEGER;
    v_id_ejemplar  INTEGER;
    v_id_empleado  INTEGER;
    v_estado_antes VARCHAR(20);
    v_estado_despues VARCHAR(20);
BEGIN
    -- Buscamos un socio que cumpla las reglas: menos de 3 préstamos activos y sin multas pendientes
    SELECT s.id_socio INTO v_id_socio
    FROM socio s
    WHERE (
        SELECT COUNT(*) FROM prestamo p
        WHERE p.id_socio = s.id_socio
          AND NOT EXISTS (SELECT 1 FROM devolucion d WHERE d.id_prestamo = p.id_prestamo)
    ) < 3
      AND NOT EXISTS (
            SELECT 1
            FROM multa m
            INNER JOIN devolucion d ON m.id_devolucion = d.id_devolucion
            INNER JOIN prestamo p2 ON d.id_prestamo = p2.id_prestamo
            WHERE p2.id_socio = s.id_socio
              AND m.pagada = FALSE
      )
    ORDER BY s.id_socio
    LIMIT 1;

    SELECT id_ejemplar INTO v_id_ejemplar FROM ejemplar WHERE estado = 'Disponible' ORDER BY id_ejemplar LIMIT 1;
    SELECT id_empleado INTO v_id_empleado FROM empleado ORDER BY id_empleado LIMIT 1;

    SELECT estado INTO v_estado_antes FROM ejemplar WHERE id_ejemplar = v_id_ejemplar;
    RAISE NOTICE 'DEMO registrar_prestamo -> estado del ejemplar ANTES: %', v_estado_antes; -- debe decir 'Disponible'

    CALL registrar_prestamo(CURRENT_DATE, CURRENT_DATE + 7, v_id_socio, v_id_ejemplar, v_id_empleado); -- ejecuta el procedimiento (y dispara trg_prestamo)

    SELECT estado INTO v_estado_despues FROM ejemplar WHERE id_ejemplar = v_id_ejemplar;
    RAISE NOTICE 'DEMO trg_prestamo -> estado del ejemplar DESPUES: %', v_estado_despues; -- debe decir 'Prestado' si el trigger funcionó
END $$;

---- DEMO 2: registrar_reserva ----
DO $$
DECLARE
    v_id_socio_reserva INTEGER;
    v_id_ejemplar       INTEGER;
    v_reservas_antes    INTEGER;
    v_reservas_despues  INTEGER;
BEGIN
    -- Tomamos el ejemplar que quedó 'Prestado' tras la DEMO 1
    SELECT id_ejemplar INTO v_id_ejemplar
    FROM prestamo
    ORDER BY id_prestamo DESC
    LIMIT 1;

    -- El socio que reserva debe ser distinto al que tiene el préstamo activo
    SELECT id_socio INTO v_id_socio_reserva
    FROM socio
    WHERE id_socio <> (SELECT id_socio FROM prestamo ORDER BY id_prestamo DESC LIMIT 1)
    ORDER BY id_socio
    LIMIT 1;

    SELECT COUNT(*) INTO v_reservas_antes FROM reserva; -- conteo antes de insertar
    RAISE NOTICE 'DEMO registrar_reserva -> reservas ANTES: %', v_reservas_antes;

    CALL registrar_reserva(CURRENT_DATE, v_id_socio_reserva, v_id_ejemplar); -- ejecuta el procedimiento corregido

    SELECT COUNT(*) INTO v_reservas_despues FROM reserva; -- conteo después de insertar
    RAISE NOTICE 'DEMO registrar_reserva -> reservas DESPUES: %', v_reservas_despues; -- debe ser ANTES + 1
END $$;


-- ---- DEMO 3: trg_devolucion + trg_generar_multa ----
DO $$
DECLARE
    v_id_prestamo     INTEGER;
    v_id_ejemplar     INTEGER;
    v_fecha_limite    DATE;
    v_estado_ejemplar VARCHAR(20);
    v_multas_generadas INTEGER;
BEGIN
    -- Reutilizamos el préstamo de la DEMO 1
    SELECT id_prestamo, id_ejemplar, fecha_limite
    INTO v_id_prestamo, v_id_ejemplar, v_fecha_limite
    FROM prestamo
    ORDER BY id_prestamo DESC
    LIMIT 1;

    INSERT INTO devolucion(fecha_devolucion, id_prestamo)
    VALUES (v_fecha_limite + 3, v_id_prestamo); -- devolución 3 días tarde: dispara trg_devolucion y trg_generar_multa

    SELECT estado INTO v_estado_ejemplar FROM ejemplar WHERE id_ejemplar = v_id_ejemplar;
    RAISE NOTICE 'DEMO trg_devolucion -> estado del ejemplar tras devolver: %', v_estado_ejemplar; -- debe volver a 'Disponible'

    SELECT COUNT(*) INTO v_multas_generadas
    FROM multa m
    INNER JOIN devolucion d ON m.id_devolucion = d.id_devolucion
    WHERE d.id_prestamo = v_id_prestamo;
    RAISE NOTICE 'DEMO trg_generar_multa -> multas generadas por el retraso: %', v_multas_generadas; -- debe ser 1
END $$;


-- ---- DEMO 4: pagar_multa ----
DO $$
DECLARE
    v_id_multa     INTEGER;
    v_pagada_antes BOOLEAN;
    v_pagada_despues BOOLEAN;
BEGIN
    -- Tomamos la multa generada en la DEMO 3
    SELECT id_multa INTO v_id_multa FROM multa ORDER BY id_multa DESC LIMIT 1;

    SELECT pagada INTO v_pagada_antes FROM multa WHERE id_multa = v_id_multa;
    RAISE NOTICE 'DEMO pagar_multa -> pagada ANTES: %', v_pagada_antes; -- debe ser FALSE

    CALL pagar_multa(v_id_multa); -- ejecuta el procedimiento

    SELECT pagada INTO v_pagada_despues FROM multa WHERE id_multa = v_id_multa;
    RAISE NOTICE 'DEMO pagar_multa -> pagada DESPUES: %', v_pagada_despues; -- debe ser TRUE
END $$;


-- ---- DEMO 5: las 3 funciones, con un socio real ----
DO $$
DECLARE
    v_id_socio INTEGER;
BEGIN
    SELECT id_socio INTO v_id_socio FROM socio ORDER BY id_socio LIMIT 1;

    RAISE NOTICE 'DEMO obtener_prestamos_socio(%) -> %', v_id_socio, obtener_prestamos_socio(v_id_socio); -- cuenta préstamos del socio
    RAISE NOTICE 'DEMO total_multas() -> %', total_multas(); -- suma de todas las multas registradas
    RAISE NOTICE 'DEMO tiene_multas_pendientes(%) -> %', v_id_socio, tiene_multas_pendientes(v_id_socio); -- TRUE/FALSE según multas impagas
END $$;


-- ---- Verificación final: triggers existentes en la base ----
SELECT trigger_name
FROM information_schema.triggers
ORDER BY trigger_name; -- confirma que los 3 disparadores quedaron creados
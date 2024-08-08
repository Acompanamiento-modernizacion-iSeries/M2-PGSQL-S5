--1. **Crear una nueva cuenta bancaria**
--Crea una nueva cuenta bancaria para un cliente, asignando un número de cuenta único y estableciendo un saldo inicial.
CREATE OR REPLACE PROCEDURE crear_cuenta_bancaria(
    p_cliente_id INTEGER,
    p_tipo_cuenta VARCHAR(20),
    p_saldo_inicial NUMERIC(12, 2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_numero_cuenta VARCHAR(20);
    v_cuenta_id INTEGER;
BEGIN
    -- Generar un número de cuenta único
    v_numero_cuenta := LPAD(CAST(nextval('cuentas_bancarias_cuenta_id_seq') AS VARCHAR), 10, '0');

    -- Insertar la nueva cuenta bancaria
    INSERT INTO cuentas_bancarias (cliente_id, numero_cuenta, tipo_cuenta, saldo, fecha_apertura, estado)
    VALUES (p_cliente_id, v_numero_cuenta, p_tipo_cuenta, p_saldo_inicial, CURRENT_DATE, 'Activa')
    RETURNING cuenta_id INTO v_cuenta_id;

    COMMIT;

    RAISE NOTICE 'Se ha creado la cuenta bancaria con el número %, para el cliente %.', v_numero_cuenta, p_cliente_id;
END;
$$;

CALL crear_cuenta_bancaria(2, 'Ahorro', 3000000);


--2. **Actualizar la información del cliente**
--Actualiza la información personal de un cliente, como dirección, teléfono y correo electrónico, basado en el ID del cliente.
CREATE OR REPLACE PROCEDURE actualizar_informacion_cliente(
    p_cliente_id INTEGER,
    p_direccion VARCHAR(200),
    p_telefono VARCHAR(20),
    p_correo_electronico VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Actualizar la información del cliente
    UPDATE clientes
    SET direccion = p_direccion,
        telefono = p_telefono,
        correo_electronico = p_correo_electronico
    WHERE cliente_id = p_cliente_id;

    COMMIT;

    RAISE NOTICE 'Se ha actualizado la información del cliente %.', p_cliente_id;
END;
$$;

CALL actualizar_informacion_cliente(2, 'Medellin, Av Guayabal 33 -20', '604123456', 'cambiocorreo@example.com');

--3. **Eliminar una cuenta bancaria**
--Elimina una cuenta bancaria específica del sistema, incluyendo la eliminación de todas las transacciones asociadas.
CREATE OR REPLACE PROCEDURE eliminar_cuenta_bancaria(
    p_cuenta_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Eliminar las transacciones asociadas a la cuenta
    DELETE FROM transacciones
    WHERE cuenta_id = p_cuenta_id;

	DELETE FROM prestamos
    WHERE cuenta_id = p_cuenta_id;

	DELETE FROM tarjetas_credito
    WHERE cuenta_id = p_cuenta_id;
	
    -- Eliminar la cuenta bancaria
    DELETE FROM cuentas_bancarias
    WHERE cuenta_id = p_cuenta_id;

    COMMIT;

    RAISE NOTICE 'Se ha eliminado la cuenta bancaria %.', p_cuenta_id;
END;
$$;

CALL eliminar_cuenta_bancaria(4);

--4. **Transferir fondos entre cuentas**
--Realiza una transferencia de fondos desde una cuenta a otra, asegurando que ambas cuentas se actualicen correctamente y se registre la transacción.
CREATE OR REPLACE PROCEDURE transferir_fondos(
    p_cuenta_origen VARCHAR(20),
    p_cuenta_destino VARCHAR(20),
    p_monto NUMERIC(12, 2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_origen_id INTEGER;
    v_cuenta_destino_id INTEGER;
BEGIN
    -- Obtener los IDs de las cuentas de origen y destino
    SELECT cuenta_id INTO v_cuenta_origen_id FROM cuentas_bancarias WHERE numero_cuenta = p_cuenta_origen;
    SELECT cuenta_id INTO v_cuenta_destino_id FROM cuentas_bancarias WHERE numero_cuenta = p_cuenta_destino;

    -- Verificar que las cuentas existan
    IF v_cuenta_origen_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta de origen no existe.';
    END IF;

    IF v_cuenta_destino_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta de destino no existe.';
    END IF;
    
    -- Actualizar el saldo de la cuenta de origen
    UPDATE cuentas_bancarias
    SET saldo = saldo - p_monto
    WHERE cuenta_id = v_cuenta_origen_id;    

    -- Actualizar el saldo de la cuenta de destino
    UPDATE cuentas_bancarias
    SET saldo = saldo + p_monto
    WHERE cuenta_id = v_cuenta_destino_id;
    

    -- Registrar la transacción
    INSERT INTO transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES
        (v_cuenta_origen_id, 'Transferencia', -p_monto, CURRENT_TIMESTAMP, 'Trans a cuenta' || p_cuenta_destino),
        (v_cuenta_destino_id, 'Transferencia', p_monto, CURRENT_TIMESTAMP, 'Trans de cuenta' || p_cuenta_origen);

    COMMIT;

    RAISE NOTICE 'Se ha realizado la transferencia de %.2f desde la cuenta % a la cuenta %.', p_monto, p_cuenta_origen, p_cuenta_destino;
END;
$$;

CALL transferir_fondos('1234567890', '2345678901', 250000.00);

--5. **Agregar una nueva transacción**
--Registra una nueva transacción (depósito, retiro) en el sistema, actualizando el saldo de la cuenta asociada.
CREATE OR REPLACE PROCEDURE registrar_transaccion(
    p_cuenta_id INTEGER,
    p_tipo_transaccion VARCHAR(20),
    p_monto NUMERIC(12, 2),
    p_descripcion TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_saldo_actual NUMERIC(12, 2);
BEGIN
    -- Verificar que la cuenta exista
    IF NOT EXISTS (SELECT 1 FROM cuentas_bancarias WHERE cuenta_id = p_cuenta_id) THEN
        RAISE EXCEPTION 'La cuenta no existe.';
    END IF;

    -- Obtener el saldo actual de la cuenta
    SELECT saldo INTO v_saldo_actual FROM cuentas_bancarias WHERE cuenta_id = p_cuenta_id;

    -- Actualizar el saldo de la cuenta
    IF p_tipo_transaccion = 'Deposito' THEN
        UPDATE cuentas_bancarias
        SET saldo = v_saldo_actual + p_monto
        WHERE cuenta_id = p_cuenta_id;
    
    ELSIF p_tipo_transaccion = 'Retiro' THEN
        IF v_saldo_actual < p_monto THEN
            RAISE EXCEPTION 'Saldo insuficiente.';
        END IF;
        UPDATE cuentas_bancarias
        SET saldo = v_saldo_actual - p_monto
        WHERE cuenta_id = p_cuenta_id
        RETURNING saldo INTO v_saldo_actual;
    ELSE
        RAISE EXCEPTION 'Tipo de transacción no válido.';
    END IF;

    -- Registrar la transacción
    INSERT INTO transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (p_cuenta_id, p_tipo_transaccion, p_monto, CURRENT_TIMESTAMP, p_descripcion);

    COMMIT;

    RAISE NOTICE 'Se ha registrado la transacción de % por un monto de %.2f. Saldo actual: %.2f', p_tipo_transaccion, p_monto, v_saldo_actual;
END;
$$;

-- Registrar un depósito de $500000 en la cuenta 1
CALL registrar_transaccion(1, 'Deposito', 500000.00, 'Depósito en efectivo');

-- Registrar un retiro de $70000 en la cuenta 1
CALL registrar_transaccion(1, 'Retiro', 70000.00, 'Retiro en cajero');

--6. **Calcular el saldo total de todas las cuentas de un cliente**
--Calcula el saldo total combinado de todas las cuentas bancarias pertenecientes a un cliente específico.
CREATE OR REPLACE PROCEDURE calcular_saldo_total_cliente(
    p_cliente_id INTEGER,
    OUT p_saldo_total NUMERIC(12, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT SUM(saldo) INTO p_saldo_total
    FROM cuentas_bancarias
    WHERE cliente_id = p_cliente_id;
END;
$$;

call calcular_saldo_total_cliente(2, 0);

--7. **Generar un reporte de transacciones para un rango de fechas**
-- Genera un reporte detallado de todas las transacciones realizadas en un rango de fechas específico.
CREATE OR REPLACE PROCEDURE generar_reporte_transacciones(
    p_fecha_inicio DATE,
    p_fecha_fin DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    CREATE TEMPORARY TABLE reporte_transacciones AS
    SELECT
        t.transaccion_id,
        t.cuenta_id,
        cb.numero_cuenta,
        c.cliente_id,
        c.nombre || ' ' || c.apellido AS nombre_cliente,
        t.tipo_transaccion,
        t.monto,
        t.fecha_transaccion,
        t.descripcion
    FROM
        transacciones t
    JOIN
        cuentas_bancarias cb ON t.cuenta_id = cb.cuenta_id
    JOIN
        clientes c ON cb.cliente_id = c.cliente_id
    WHERE
        t.fecha_transaccion BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY
        t.fecha_transaccion DESC;

    RAISE NOTICE 'Se ha generado el reporte de transacciones entre % y %.', p_fecha_inicio, p_fecha_fin;
END;
$$;

CALL generar_reporte_transacciones('2023-01-15', '2023-01-17');

select * from reporte_transacciones;
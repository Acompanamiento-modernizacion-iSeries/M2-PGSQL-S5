--1. Crear una nueva cuenta bancaria
--Crea una nueva cuenta bancaria para un cliente, 
--asignando un número de cuenta único y estableciendo un saldo inicial.

CREATE OR REPLACE PROCEDURE crear_cuenta_bancaria(
    p_cliente_id INT,
    p_saldo_inicial NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO cuentas (cliente_id, saldo)
    VALUES (p_cliente_id, p_saldo_inicial);
END;
$$;

--2. Actualizar la información del cliente
--Actualiza la información personal de un cliente, como dirección,
--teléfono y correo electrónico, basado en el ID del cliente.

CREATE OR REPLACE PROCEDURE actualizar_informacion_cliente(
    p_cliente_id INT,
    p_direccion VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Clientes
    SET direccion = p_direccion,
        telefono = p_telefono,
        correo_electronico = p_correo
    WHERE id = p_cliente_id;
END;
$$;

--3. Eliminar una cuenta bancaria
--Elimina una cuenta bancaria específica del sistema, 
--incluyendo la eliminación de todas las transacciones asociadas.

CREATE OR REPLACE PROCEDURE eliminar_cuenta_bancaria(
    p_cuenta_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Eliminar transacciones asociadas
    DELETE FROM Transacciones
    WHERE cuenta_id = p_cuenta_id;

    -- Eliminar la cuenta bancaria
    DELETE FROM Cuentas
    WHERE id = p_cuenta_id;
END;
$$;

--4. Transferir fondos entre cuentas
--Realiza una transferencia de fondos desde una cuenta a otra, 
--asegurando que ambas cuentas se actualicen correctamente y se registre la transacción.

CREATE OR REPLACE PROCEDURE transferir_fondos(
    p_cuenta_origen INT,
    p_cuenta_destino INT,
    p_monto NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verificar si hay saldo suficiente en la cuenta de origen
    IF (SELECT Saldo FROM Cuentas WHERE id = p_cuenta_origen) < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente en la cuenta de origen';
    END IF;

    -- Debitar el monto de la cuenta de origen
    UPDATE Cuentas
    SET saldo = saldo - p_monto
    WHERE id = p_cuenta_origen;

    -- Acreditar el monto en la cuenta de destino
    UPDATE Cuentas
	SET saldo = saldo + p_monto
    WHERE id = p_cuenta_destino;

    -- Registrar la transacción en la cuenta de origen
    INSERT INTO Transacciones (cuenta_id, tipo_transaccion, monto)
    VALUES (p_cuenta_origen, 'debito', p_monto);

    -- Registrar la transacción en la cuenta de destino
    INSERT INTO Transacciones (cuenta_id, tipo_transaccion, monto)
    VALUES (p_cuenta_destino, 'credito', p_monto);
END;
$$;


--5. Agregar una nueva transacción
--Registra una nueva transacción (depósito, retiro) en el sistema,
--actualizando el saldo de la cuenta asociada.

CREATE OR REPLACE PROCEDURE agregar_transaccion(
    p_cuenta_id INT,
    p_tipo VARCHAR,
    p_monto NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Actualizar el saldo de la cuenta
    IF p_tipo = 'deposito' THEN
        UPDATE Cuentas 
        SET saldo = saldo + p_monto
        WHERE id = p_cuenta_id;
    ELSIF p_tipo = 'retiro' THEN
        IF (SELECT saldo FROM Cuentas WHERE id = p_cuenta_id) < p_monto THEN
            RAISE EXCEPTION 'Saldo insuficiente para realizar el retiro';
        END IF;
        UPDATE Cuentas
        SET saldo = saldo - p_monto
        WHERE id = p_cuenta_id;
    ELSE
        RAISE EXCEPTION 'Tipo de transacción no reconocido';
    END IF;

    -- Registrar la transacción
    INSERT INTO Transacciones (cuenta_id, tipo_transaccion, monto)
    VALUES (p_cuenta_id, p_tipo, p_monto);
END;
$$;


--6. Calcular el saldo total de todas las cuentas de un cliente
--Calcula el saldo total combinado de todas las 
--cuentas bancarias pertenecientes a un cliente específico.

CREATE OR REPLACE FUNCTION calcular_saldo_total_cliente(
    IN p_cliente_id INT,
    OUT saldo_total NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT SUM(saldo)
    INTO saldo_total
    FROM Cuentas
    WHERE cliente_id = p_cliente_id;
END;
$$;

--7. Generar un reporte de transacciones para un rango de fechas
--Genera un reporte detallado de todas las 
--transacciones realizadas en un rango de fechas específico.

CREATE OR REPLACE PROCEDURE reporte_transacciones(
    p_fecha_inicio DATE,
    p_fecha_fin DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM 
    FROM Transacciones
    WHERE fecha_transaccion BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY fecha;
END;
$$;
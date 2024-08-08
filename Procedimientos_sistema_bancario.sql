-----------------------------------------------------------------------
--TALLER 5
--SCRIPT CREADO POR: JUAN PABLO VALDERRAMA PELÁEZ
--CREACIÓN PROCEDIMIENTOS SOBRE BASE DE DATOS SISTEMA BANCARIO 
------------------------------------------------------------------------
--1.Crea una nueva cuenta bancaria para un cliente, asignando un número 
--  de cuenta único y estableciendo un saldo inicial.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Crear_Cuenta(
    p_cliente_id INT,
    p_tipo_cuenta INT,
    p_saldo NUMERIC(15, 2),
    p_fecha_apertura TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
LANGUAGE plpgsql AS $$

-- Declaración de variables procedimiento.
DECLARE
    v_numero_cuenta INT;
    v_estado_cuenta INT := 1;  -- Estado por defecto 'Activa'.
    v_cliente_existe BOOLEAN;
BEGIN
    -- Validar si el cliente ya está creado en la base de datos.
    SELECT EXISTS (SELECT 1 FROM Clientes WHERE cliente_id = p_cliente_id) 
	INTO v_cliente_existe;
    
	-- Si el cliente no existe hay error, debe crearse primero.
    IF NOT v_cliente_existe THEN
        RAISE EXCEPTION 'El cliente con ID % no existe, debe crearse primero como cliente', 
		p_cliente_id;
    END IF;

    -- Generar un número de cuenta único (valores entre 10,000,000 y 99,999,999) asegurando que sea de 8 dígitos.
	-- y que no exista ya como un número de cuenta en la tabla de cuentas.
    LOOP
        v_numero_cuenta := floor(random() * (99999999 - 10000000 + 1) + 10000000);
        EXIT WHEN NOT EXISTS (SELECT 1 FROM Cuentas_Bancarias WHERE numero_cuenta = v_numero_cuenta);
    END LOOP;

    -- Insertar la nueva cuenta bancaria.
    INSERT INTO Cuentas_Bancarias (cliente_id, numero_cuenta, tipo_cuenta, saldo, fecha_apertura, estado)
    VALUES (p_cliente_id, v_numero_cuenta, p_tipo_cuenta, p_saldo, p_fecha_apertura, v_estado_cuenta);
END;
$$;

--Llamado al procedimiento.
CALL Crear_Cuenta(1, 2, 50000.00);

--Validación de los datos creados.
SELECT * FROM Cuentas_Bancarias;

------------------------------------------------------------------------
--2.Actualiza la información personal de un cliente, como dirección, 
--  teléfono y correo electrónico, basado en el ID del cliente.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Actualizar_Informacion_Cliente(
    p_cliente_id INT,
    p_direccion VARCHAR,
    p_telefono VARCHAR,
    p_correo_electronico VARCHAR
)
LANGUAGE plpgsql AS $$

-- Declaración de variables procedimiento.
DECLARE
    v_cliente_existe BOOLEAN;
BEGIN
    -- Validar si el cliente existe en la base de datos.
    SELECT EXISTS (SELECT 1 FROM Clientes WHERE cliente_id = p_cliente_id) 
	INTO v_cliente_existe;
    
	-- Si el cliente no existe se debe mostrar error.
    IF NOT v_cliente_existe THEN
        RAISE EXCEPTION 'El cliente con ID % no existe, no es posible actualizar su información', 
		p_cliente_id;
    END IF;

    -- Actualizar la información del cliente ya existente.
    UPDATE Clientes
    SET direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        correo_electronico = COALESCE(p_correo_electronico, correo_electronico)
    WHERE cliente_id = p_cliente_id;
END;
$$;

--Llamado al procedimiento.
CALL Actualizar_Informacion_Cliente(1, 'Carrera 59 #70-349', '3104376767', 'juanpablo_valderrama@gmail.com');

--Validación de los datos actualizados.
SELECT * FROM Clientes;

------------------------------------------------------------------------
--3.Elimina una cuenta bancaria específica del sistema, incluyendo la 
--  eliminación de todas las transacciones asociadas.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Eliminar_Cuenta(
    p_numero_cuenta INT
)
LANGUAGE plpgsql AS $$

-- Declaración de variables procedimiento.
DECLARE
    v_cuenta_id INT;
    v_cuenta_existe BOOLEAN;
BEGIN
    -- Obtener el ID de la cuenta bancaria basada en el número de cuenta.
    SELECT cuenta_id 
	INTO v_cuenta_id
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_numero_cuenta;

     -- Validar si la cuenta bancaria existe o mostrar error.
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta bancaria con número de cuenta % no existe', 
		p_numero_cuenta;
    END IF;
    
	-- Se deben eliminar todas las tablas relacionadas con cuenta bancaria.

    -- Eliminar transacciones asociadas a la cuenta bancaria.
    DELETE FROM Transacciones 
	WHERE cuenta_id = v_cuenta_id;

    -- Eliminar préstamos asociados a la cuenta bancaria.
    DELETE FROM Prestamos 
	WHERE cuenta_id = v_cuenta_id;

    -- Eliminar tarjetas de crédito asociadas a la cuenta bancaria.
    DELETE FROM Tarjetas_Credito 
	WHERE cuenta_id = v_cuenta_id;

    -- Eliminar la cuenta bancaria.
    DELETE FROM Cuentas_Bancarias 
	WHERE cuenta_id = v_cuenta_id;
END;
$$;

--Llamado al procedimiento.
CALL Eliminar_Cuenta(5437688);

--Validación de los datos eliminados.
SELECT * FROM Transacciones;
SELECT * FROM Prestamos;
SELECT * FROM Tarjetas_Credito;
SELECT * FROM Cuentas_Bancarias;

------------------------------------------------------------------------
--4.Realiza una transferencia de fondos desde una cuenta a otra, 
--  asegurando que ambas cuentas se actualicen correctamente y 
--  se registre la transacción.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Transferencia(
    p_numero_cuenta_origen INT,
    p_numero_cuenta_destino INT,
    p_monto NUMERIC(15, 2),
    p_descripcion VARCHAR(200)
)
LANGUAGE plpgsql AS $$

-- Declaración de variables procedimiento.
DECLARE
    v_id_cuenta_origen INT;
    v_id_cuenta_destino INT;
    v_saldo_origen NUMERIC(15, 2);
    v_saldo_destino NUMERIC(15, 2);
BEGIN
    -- Obtener el ID de la cuenta de origen y su saldo actual.
    SELECT cuenta_id, saldo 
	INTO v_id_cuenta_origen, v_saldo_origen
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_numero_cuenta_origen;

    -- Verificar si la cuenta de origen existe, sino se muestra error.
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta bancaria origen con número de cuenta % no existe, no es posible realizar transferencia'
		, p_numero_cuenta_origen;
    END IF;

    -- Obtener el ID de la cuenta de destino y su saldo actual.
    SELECT cuenta_id, saldo 
	INTO v_id_cuenta_destino, v_saldo_destino
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_numero_cuenta_destino;

    -- Verificar si la cuenta de destino existe, sino se muestra error.
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta bancaria destino con número de cuenta % no existe, no es posible realizar transferencia'
		, p_numero_cuenta_destino;
    END IF;

    -- Validar si hay suficiente saldo en la cuenta de origen
    IF v_saldo_origen < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente en la cuenta de origen, transferencia cancelada.';
    END IF;

    -- Actualizar el saldo de la cuenta de origen.
    UPDATE Cuentas_Bancarias
    SET saldo = saldo - p_monto
    WHERE cuenta_id = v_id_cuenta_origen;

    -- Actualizar el saldo de la cuenta de destino.
    UPDATE Cuentas_Bancarias
    SET saldo = saldo + p_monto
    WHERE cuenta_id = v_id_cuenta_destino;

    -- Registrar la transacción en la tabla de transacciones
    INSERT INTO Transacciones(cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (v_id_cuenta_origen, (SELECT tipo_id FROM Tipo_Transaccion WHERE nombre = 'Transferencia'), 
	        p_monto, CURRENT_TIMESTAMP, p_descripcion);
        
    INSERT INTO Transacciones(cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (v_id_cuenta_destino, (SELECT tipo_id FROM Tipo_Transaccion WHERE nombre = 'Transferencia'), 
	     	p_monto, CURRENT_TIMESTAMP, p_descripcion);

END;
$$;

--Llamado al procedimiento.
CALL Transferencia(10987621,11786521,500000,'Transferencia entre cuentas');

--Validación de los datos actualizados y creados.
SELECT * FROM Cuentas_Bancarias;
SELECT * FROM Transacciones;

------------------------------------------------------------------------
--5.Registra una nueva transacción (depósito, retiro) en el sistema, 
--actualizando el saldo de la cuenta asociada.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Transaccion(
    p_numero_cuenta INT,
    p_tipo_transaccion VARCHAR(100),
    p_monto NUMERIC(15, 2),
    p_descripcion VARCHAR(200)
)
LANGUAGE plpgsql AS $$

-- Declaración de variables del procedimiento.
DECLARE
    v_cuenta_id INT;
    v_saldo NUMERIC(15, 2);
    v_tipo_transaccion_id INT;
BEGIN
    -- Obtener el ID de la cuenta y su saldo actual.
    SELECT cuenta_id, saldo 
    INTO v_cuenta_id, v_saldo
    FROM Cuentas_Bancarias
    WHERE numero_cuenta = p_numero_cuenta;

    -- Verificar si la cuenta existe, sino se muestra error.
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La cuenta bancaria con número de cuenta % no existe, no es posible realizar la transacción.',
        p_numero_cuenta;
    END IF;

    -- Obtener el ID del tipo de transacción.
    SELECT tipo_id 
    INTO v_tipo_transaccion_id
    FROM Tipo_Transaccion
    WHERE nombre = p_tipo_transaccion;

    -- Verificar si el tipo de transacción es válido, sino se muestra error.
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El tipo de transacción % no existe.', p_tipo_transaccion;
    END IF;

    -- Realizar la transacción según el tipo.
    IF p_tipo_transaccion = 'Depósito' THEN
        -- Actualizar el saldo de la cuenta.
        UPDATE Cuentas_Bancarias
        SET saldo = saldo + p_monto
        WHERE cuenta_id = v_cuenta_id;
        
    ELSIF p_tipo_transaccion = 'Retiro' THEN
        -- Verificar si hay suficiente saldo para el retiro.
        IF v_saldo < p_monto THEN
            RAISE EXCEPTION 'Saldo insuficiente en la cuenta para realizar el retiro. Saldo actual: %. Monto a retirar: %',
                            v_saldo, p_monto;
        END IF;
        
        -- Actualizar el saldo en caso de retiro.
        UPDATE Cuentas_Bancarias
        SET saldo = saldo - p_monto
        WHERE cuenta_id = v_cuenta_id;
        
    ELSE
        RAISE EXCEPTION 'Tipo de transacción inválido. Use "Depósito" o "Retiro".';
    END IF;

    -- Registrar la transacción en la tabla de transacciones.
    INSERT INTO Transacciones(cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (v_cuenta_id, v_tipo_transaccion_id, p_monto, CURRENT_TIMESTAMP, p_descripcion);

END;
$$;

--Llamado al procedimiento.
CALL Transaccion(10987621, 'Retiro', 100, 'Retiro Cajero');

--Validación de los datos creados y actualizados.
SELECT * FROM Cuentas_Bancarias;
SELECT * FROM Transacciones;

------------------------------------------------------------------------
--6.Calcula el saldo total combinado de todas las cuentas bancarias
--  pertenecientes a un cliente específico.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Calcular_Saldo_Cliente(
    p_cliente_id INT
)
LANGUAGE plpgsql AS $$

-- Declaración de variables del procedimiento.
DECLARE
    v_saldo_total NUMERIC(15, 2);
BEGIN
    -- Calcular el saldo total combinado de todas las cuentas del cliente.
    SELECT SUM(saldo)
    INTO v_saldo_total
    FROM Cuentas_Bancarias
    WHERE cliente_id = p_cliente_id;
    
    -- Verificar si el cliente tiene cuentas.
    IF v_saldo_total IS NULL THEN
        RAISE EXCEPTION 'El cliente con ID % no tiene cuentas bancarias.', p_cliente_id;
    END IF;
	
	-- Mostrar el saldo total.
    RAISE NOTICE 'El saldo total del cliente con ID % es: $%.', p_cliente_id, v_saldo_total;
END;
$$;

--Llamado al procedimiento.
CALL Calcular_Saldo_Cliente(2);

--Validación de los datos.
SELECT * FROM Cuentas_Bancarias;

------------------------------------------------------------------------
--7.Genera un reporte detallado de todas las transacciones realizadas
--  en un rango de fechas específico.
------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE 
Reporte_Transacciones(
    p_fecha_inicio TIMESTAMP,
    p_fecha_fin TIMESTAMP
)
LANGUAGE plpgsql AS $$

-- Declaración de variables procedimiento.
DECLARE
    transaccion RECORD;
BEGIN
    -- Verificar que el rango de fechas es válido.
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE EXCEPTION 'La fecha de inicio % no puede ser mayor a la fecha de fin %.',
            p_fecha_inicio, p_fecha_fin;
    END IF;
    
    -- Generar el reporte detallado de transacciones en el rango de fechas.
    RAISE NOTICE 'Reporte de transacciones desde % hasta %:', p_fecha_inicio, p_fecha_fin;
    
	-- Ciclo para ir mostrando por mensaje cada transacción.
    FOR transaccion IN
        SELECT t.transaccion_id, c.numero_cuenta, tt.nombre AS tipo_transaccion, t.monto, t.fecha_transaccion,
		t.descripcion
        FROM Transacciones t
        JOIN Cuentas_Bancarias c ON t.cuenta_id = c.cuenta_id
        JOIN Tipo_Transaccion tt ON t.tipo_transaccion = tt.tipo_id
        WHERE t.fecha_transaccion BETWEEN p_fecha_inicio AND p_fecha_fin
    LOOP
        RAISE NOTICE 'ID Transacción: %, Número de Cuenta: %, Tipo: %, Monto: %, Fecha: %, Descripción: %',
            transaccion.transaccion_id, transaccion.numero_cuenta, transaccion.tipo_transaccion, 
            transaccion.monto, transaccion.fecha_transaccion, transaccion.descripcion;
    END LOOP;

    -- Mensaje final.
    RAISE NOTICE 'Fin reporte generado.';
END;
$$;

--Llamado al procedimiento.
CALL Reporte_Transacciones('2024-07-24 00:00:00','2024-07-31 00:00:00');

--Validación de los datos.
SELECT * FROM Transacciones;

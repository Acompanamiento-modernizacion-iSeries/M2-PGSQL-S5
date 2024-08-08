#1
CREATE OR REPLACE FUNCTION crear_nueva_cuenta(
    p_cliente_id INT,
    p_numero_cuenta VARCHAR,
    p_tipo_cuenta VARCHAR,
    p_saldo NUMERIC,
    p_fecha_apertura DATE,
    p_estado VARCHAR
) RETURNS VOID AS $$
BEGIN
    INSERT INTO CuentasBancarias (cliente_id, numero_cuenta, tipo_cuenta, saldo, fecha_apertura, estado)
    VALUES (p_cliente_id, p_numero_cuenta, p_tipo_cuenta, p_saldo, p_fecha_apertura, p_estado);
END;
$$ LANGUAGE plpgsql;

SELECT crear_nueva_cuenta(
    p_cliente_id := 1,
    p_numero_cuenta := '123456789',
    p_tipo_cuenta := 'ahorro',
    p_saldo := 1000.00,
    p_fecha_apertura := '2024-08-01',
    p_estado := 'activa'
);

select * from cuentasbancarias;

#2
CREATE OR REPLACE FUNCTION actualizar_informacion_cliente(
    p_cliente_id INT,
    p_direccion VARCHAR,
    p_telefono VARCHAR,
    p_correo_electronico VARCHAR
) RETURNS VOID AS $$
BEGIN
    UPDATE Clientes
    SET direccion = p_direccion,
        telefono = p_telefono,
        correo_electronico = p_correo_electronico
    WHERE cliente_id = p_cliente_id;
END;
$$ LANGUAGE plpgsql;


SELECT actualizar_informacion_cliente(
    p_cliente_id := 1,
    p_direccion := 'Nueva Calle 123',
    p_telefono := '555-1234',
    p_correo_electronico := 'cliente1@ejemplo.com'
);

select * from clientes;

#3
CREATE OR REPLACE FUNCTION eliminar_cuenta_bancaria(p_cuenta_id INT) RETURNS VOID AS $$
BEGIN
	DELETE FROM Prestamos WHERE cuenta_id = p_cuenta_id;
	DELETE FROM TarjetasDeCrédito WHERE cuenta_id = p_cuenta_id;
    DELETE FROM Transacciones WHERE cuenta_id = p_cuenta_id;
    DELETE FROM CuentasBancarias WHERE cuenta_id = p_cuenta_id;
END;
$$ LANGUAGE plpgsql;

SELECT eliminar_cuenta_bancaria(p_cuenta_id := 2);

select * from CuentasBancarias;

#4
CREATE OR REPLACE FUNCTION transferir_fondos(
    p_cuenta_origen INT,
    p_cuenta_destino INT,
    p_monto NUMERIC
) RETURNS VOID AS $$
BEGIN
    -- Verificar si hay suficiente saldo
    IF (SELECT saldo FROM CuentasBancarias WHERE cuenta_id = p_cuenta_origen) < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente en la cuenta de origen';
    END IF;
    UPDATE CuentasBancarias
    SET saldo = saldo - p_monto
    WHERE cuenta_id = p_cuenta_origen;
    UPDATE CuentasBancarias
    SET saldo = saldo + p_monto
    WHERE cuenta_id = p_cuenta_destino;
    INSERT INTO Transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (p_cuenta_origen, 'retiro', p_monto, CURRENT_DATE, 'Transferencia a cuenta ' || p_cuenta_destino);

    INSERT INTO Transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (p_cuenta_destino, 'depósito', p_monto, CURRENT_DATE, 'Transferencia desde cuenta ' || p_cuenta_origen);
END;
$$ LANGUAGE plpgsql;

-- Llamada a la función para transferir fondos entre cuentas
SELECT transferir_fondos(
    p_cuenta_origen := 3,
    p_cuenta_destino := 4,
    p_monto := 200.00
);
select * from cuentasbancarias

#5
CREATE OR REPLACE FUNCTION agregar_transaccion(
    p_cuenta_id INT,
    p_tipo_transaccion VARCHAR,
    p_monto NUMERIC,
    p_fecha_transaccion DATE,
    p_descripcion TEXT
) RETURNS VOID AS $$
BEGIN
    IF p_tipo_transaccion = 'depósito' THEN
        UPDATE CuentasBancarias
        SET saldo = saldo + p_monto
        WHERE cuenta_id = p_cuenta_id;
    ELSIF p_tipo_transaccion = 'retiro' THEN
        UPDATE CuentasBancarias
        SET saldo = saldo - p_monto
        WHERE cuenta_id = p_cuenta_id;
    ELSE
        RAISE EXCEPTION 'Tipo de transacción no válido';
    END IF;

    INSERT INTO Transacciones (cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion)
    VALUES (p_cuenta_id, p_tipo_transaccion, p_monto, p_fecha_transaccion, p_descripcion);
END;
$$ LANGUAGE plpgsql;

SELECT agregar_transaccion(
    p_cuenta_id := 3,
    p_tipo_transaccion := 'retiro',
    p_monto := 150.00,
    p_fecha_transaccion := '2024-08-05',
    p_descripcion := 'Retiro en cajero automático'
);

select * from transacciones;

#6
CREATE OR REPLACE FUNCTION calcular_saldo_total_cliente(p_cliente_id INT) RETURNS NUMERIC AS $$
DECLARE
    saldo_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(saldo), 0)
    INTO saldo_total
    FROM CuentasBancarias
    WHERE cliente_id = p_cliente_id;

    RETURN saldo_total;
END;
$$ LANGUAGE plpgsql;

SELECT calcular_saldo_total_cliente(p_cliente_id := 1);

#7
CREATE OR REPLACE FUNCTION reporte_transacciones_total(
    p_fecha_inicio timestamp,
    p_fecha_fin timestamp
) RETURNS TABLE (
    transaccion_id INT,
    cuenta_id INT,
    tipo_transaccion VARCHAR,
    monto NUMERIC,
    fecha_transaccion timestamp,
    descripcion VARCHAR
)  language plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT t.transaccion_id, t.cuenta_id, t.tipo_transaccion, t.monto, t.fecha_transaccion, t.descripcion
    FROM Transacciones t
    WHERE t.fecha_transaccion BETWEEN p_fecha_inicio AND p_fecha_fin;
END;
$$;

select * from reporte_transacciones_total('2021-01-01', '2024-12-12');
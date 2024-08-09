-- 1.Crear una nueva cuenta bancaria
CREATE or REPLACE PROCEDURE CrearNuevaCuentaBancaria(
	IN Cuentaid  INT, 
	IN Clienteid INT,
	IN Numerocuenta VARCHAR,
	IN Tipocuenta VARCHAR, 
    IN Saldoinicial DECIMAL(15, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
	IF Saldoinicial = 0 THEN
		RAISE EXCEPTION 'Saldo inicial no puede ser 0';
	END IF;
	
    INSERT INTO Cuentas_bancarias (Cuenta_id, Cliente_id, Numero_cuenta, Tipo_cuenta, Saldo)
    VALUES (Cuentaid, Clienteid, Numerocuenta, Tipocuenta, Saldoinicial);
END;
$$;

CALL CrearNuevaCuentaBancaria(9, 2, '123487954', 'ahorro', 1000.00);

-- 2. Actualizar la información del cliente

CREATE or REPLACE PROCEDURE ActualizarInformacionCliente(
	IN PClienteid INT,
	IN PDireccion VARCHAR,
	IN PTelefono VARCHAR, 
    IN PCorreo VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
	
    UPDATE Clientes set direccion = PDireccion, 
	telefono = PTelefono, correo_electronico = PCorreo
	WHERE Cliente_id = PClienteid;
	
END;
$$;

CALL ActualizarInformacionCliente(1, 'Calle 456', '3211234567','juan.perez@icloud.com');

-- 3.Eliminar una cuenta bancaria

CREATE or REPLACE PROCEDURE EliminarCuentaBancaria(
	IN PCuentaid INT
)
LANGUAGE plpgsql
AS $$
BEGIN

    DELETE FROM Transacciones
	WHERE Cuenta_id= PCuentaid;
	
	DELETE FROM Prestamos
	WHERE Cuenta_id= PCuentaid;
	
	DELETE FROM Tarjetas_credito
	WHERE Cuenta_id= PCuentaid;
	
    DELETE FROM Cuentas_bancarias 
	WHERE Cuenta_id= PCuentaid;
	
END;
$$;

CALL EliminarCuentaBancaria(3);

-- 4.Transferir fondos entre cuentas
CREATE or REPLACE PROCEDURE TransferirFondosEntreCuentas(
	IN PCuentain INT,
	IN PCuentasa INT,
	IN PValor DECIMAL(15, 2)
)
LANGUAGE plpgsql
AS $$
	DECLARE 
	VTipotransaccion VARCHAR(20);
	VDescripcion VARCHAR(200);
BEGIN
	BEGIN
	
	IF (SELECT saldo FROM Cuentas_bancarias WHERE Cuenta_id = PCuentasa) >= PValor THEN
	
		UPDATE Cuentas_bancarias set saldo = (saldo - Pvalor)
		WHERE Cuenta_id = PCuentasa;
	
		VTipotransaccion = 'retiro';
		VDescripcion = 'Retiro a cuenta mismo cliente';
	
		INSERT INTO Transacciones (Cuenta_id, Tipo_transaccion, Monto, Descripcion)
		VALUES (PCuentasa, VTipotransaccion, PValor, VDescripcion);
	
		UPDATE Cuentas_bancarias set saldo = (saldo + Pvalor)
		WHERE Cuenta_id = PCuentain;
	
		VTipotransaccion = 'depósito';
		VDescripcion = 'Deposito desde cuenta mismo cliente';
	
		INSERT INTO Transacciones (Cuenta_id, Tipo_transaccion, Monto, Descripcion)
		VALUES (PCuentain, VTipotransaccion, PValor, VDescripcion);
	ELSE
		RAISE EXCEPTION 'Saldo insuficiente en la cuenta de origen';
	END IF;	
	
	EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
END;
$$;

Call TransferirFondosEntreCuentas(2, 8, 500.00);

-- 5. Agregar una nueva transacción
CREATE or REPLACE PROCEDURE AgregarNuevaTransaccion(
	IN PCuentain INT,
	IN PValor DECIMAL(15, 2),
	IN PTipotransaccion VARCHAR
)
LANGUAGE plpgsql
AS $$
	DECLARE 
	VDescripcion VARCHAR(200);
BEGIN
	BEGIN
	
	IF PTipotransaccion = 'retiro' THEN
		IF (SELECT saldo FROM Cuentas_bancarias WHERE Cuenta_id = PCuentain) >= PValor THEN
		
			UPDATE Cuentas_bancarias set saldo = (saldo - Pvalor)
			WHERE Cuenta_id = PCuentain;
	
			VDescripcion = 'Retiro de dinero';
	
			INSERT INTO Transacciones (Cuenta_id, Tipo_transaccion, Monto, Descripcion)
			VALUES (PCuentain, PTipotransaccion, PValor, VDescripcion);
		ELSE
			RAISE EXCEPTION 'Saldo insuficiente en la cuenta de origen';
		END IF;
	ELSE
		IF PTipotransaccion = 'depósito' THEN
		
			UPDATE Cuentas_bancarias set saldo = (saldo + Pvalor)
			WHERE Cuenta_id = PCuentain;
	
			VDescripcion = 'Deposito de dinero';
	
			INSERT INTO Transacciones (Cuenta_id, Tipo_transaccion, Monto, Descripcion)
			VALUES (PCuentain, PTipotransaccion, PValor, VDescripcion);
		ELSE
			RAISE EXCEPTION 'Tipo de transaccion no valida';
		END IF;
	END IF;	
	
	EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
END;
$$;

Call AgregarNuevaTransaccion(2, 3500.00, 'depósito');

-- 6. Calcular el saldo total de todas las cuentas de un cliente
CREATE or REPLACE PROCEDURE CalculaSaldoTotal(
	IN PClienteid INT
)
LANGUAGE plpgsql
AS $$
DECLARE 
	VSaldototal DECIMAL(15,2) DEFAULT 0;
BEGIN
	SELECT SUM(saldo) into VSaldototal FROM Cuentas_bancarias
	WHERE Cliente_id = PClienteid;
	
	IF VSaldototal IS NULL THEN
		RAISE NOTICE 'Cliente no existe';
	ELSE
		RAISE NOTICE 'El saldo total para el cliente % es: %', PClienteid, VSaldototal;
	END IF;
END;
$$;

Call CalculaSaldoTotal(4);

-- 7. Generar un reporte de transacciones para un rango de fechas
CREATE OR REPLACE PROCEDURE generarReporteRransacciones(
	Pfechainicio TIMESTAMP, 
	Pfechafin TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    transaccion RECORD;
BEGIN
    RAISE NOTICE 'Reporte de transacciones desde % hasta %', Pfechainicio, Pfechafin;

    FOR transaccion IN
        SELECT Transaccion_id, Cuenta_id, Tipo_transaccion, Monto, Fecha_transaccion, Descripcion
        FROM transacciones
        WHERE Fecha_transaccion BETWEEN Pfechainicio AND Pfechafin
    LOOP
        RAISE NOTICE 'Transaccion id: %, Cuenta id: %, Tipo transaccion: %, Monto: %, Fecha transaccion: %, Descripción: %',
            transaccion.Transaccion_id, transaccion.Cuenta_id, transaccion.Tipo_transaccion, 
			transaccion.Monto, transaccion.Fecha_transaccion, transaccion.Descripcion;
    END LOOP;
END;
$$;

CALL generarReporteRransacciones('2023-01-01 00:00:00', '2024-08-01 23:59:59');
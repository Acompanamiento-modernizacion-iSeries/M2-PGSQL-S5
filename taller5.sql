-- 1. Crear una nueva cuenta bancaria
CREATE OR REPLACE PROCEDURE crear_cuenta_bancaria(
	par_cliente_id INTEGER,
	par_tipo_cuenta VARCHAR (20),
	par_saldo DECIMAL (15,2)
)language plpgsql
as $$
	declare 
		var_numero_cuenta VARCHAR(50);
		var_existe_cliente boolean;
		var_existe_cuenta boolean = false;
	
	begin
		SELECT EXISTS (SELECT 1 FROM clientes WHERE cliente_id = par_cliente_id) INTO var_existe_cliente;
		
		IF NOT var_existe_cliente THEN 
			RAISE EXCEPTION 'El id del cliente no es valido: %', par_cliente_id;
		END IF;
		
		LOOP
			SELECT trunc(random() * 99999999 + 1) FROM generate_series(1,1) INTO var_numero_cuenta;
			EXIT WHEN NOT EXISTS (SELECT 1 FROM cuentas_bancarias WHERE numero_cuenta = var_numero_cuenta);
		END LOOP;
		
		INSERT INTO cuentas_bancarias(cliente_id, numero_cuenta, tipo_cuenta, saldo)
		VALUES (par_cliente_id, var_numero_cuenta, par_tipo_cuenta, par_saldo);
	END;
$$;

CALL crear_cuenta_bancaria(1, 'ahorro', 500.00);

-- 2. Actualizar la información del cliente
CREATE OR REPLACE PROCEDURE update_info_cliente(
	par_cliente_id INTEGER,
	par_direccion VARCHAR (100),
	par_telefono VARCHAR (20),
	par_correo_electronico VARCHAR (200)
)language plpgsql
as $$
	DECLARE
		var_cliente_existe boolean;
	begin
		SELECT EXISTS(SELECT 1 FROM clientes where cliente_id = par_cliente_id) INTO var_cliente_existe;
		
		IF NOT var_cliente_existe THEN
			RAISE EXCEPTION 'El id del cliente no es valido: %', par_cliente_id;
		END IF;
		
		UPDATE clientes SET direccion = par_direccion, telefono = par_telefono, correo_electronico = par_correo_electronico
		WHERE cliente_id = par_cliente_id;
	end;
$$;

CALL update_info_cliente(1, 'KR10', '0123456789', 'JAA@GMAIL.COM');

-- 3.Eliminar una cuenta bancaria
CREATE OR REPLACE PROCEDURE eliminar_cuenta_bancaria(
	par_cuenta_id INTEGER
)language plpgsql
as $$
	DECLARE
		var_existe_cuenta boolean;
	BEGIN
		SELECT EXISTS(SELECT 1 FROM cuentas_bancarias where cuenta_id = par_cuenta_id) INTO var_existe_cuenta;
		
		IF NOT var_existe_cuenta THEN
			RAISE EXCEPTION 'El id de la cuenta no es existe: %', par_cuenta_id;
		END IF;
		
		DELETE FROM transacciones WHERE cuenta_id = par_cuenta_id;
		DELETE FROM prestamos WHERE cuenta_id = par_cuenta_id;
		DELETE FROM tarjetascredito WHERE cuenta_id = par_cuenta_id;
		DELETE FROM cuentas_bancarias WHERE cuenta_id = par_cuenta_id;
	END;
$$;

CALL eliminar_cuenta_bancaria(11);

-- 4.Transferir fondos entre cuentas
CREATE OR REPLACE PROCEDURE transferir_cuenta_bancaria(
	par_cuenta_id_origen INTEGER,
	par_saldo DECIMAL (15,2),
	par_cuenta_id_destino INTEGER
)language plpgsql
as $$
	DECLARE
		var_existe_cuenta_origen boolean;
		var_existe_cuenta_destino boolean;
		var_existe_saldo boolean;
	BEGIN
		SELECT EXISTS(SELECT 1 FROM cuentas_bancarias where cuenta_id = par_cuenta_id_origen) INTO var_existe_cuenta_origen;
		SELECT EXISTS(SELECT 1 FROM cuentas_bancarias where cuenta_id = par_cuenta_id_destino) INTO var_existe_cuenta_destino;
		SELECT EXISTS(SELECT 1 FROM cuentas_bancarias where cuenta_id = par_cuenta_id_origen AND saldo >= par_saldo) 
			INTO var_existe_saldo;
		
		IF NOT var_existe_cuenta_origen THEN
			RAISE EXCEPTION 'El id de la cuenta no es existe: %', par_cuenta_id_origen;
		END IF;
		
		IF NOT var_existe_cuenta_destino THEN
			RAISE EXCEPTION 'El id de la cuenta no es existe: %', par_cuenta_id_destino;
		END IF;
		
		IF NOT var_existe_saldo THEN
			RAISE EXCEPTION 'No cuenta con saldo suficiente para la transferiencia: %', par_saldo;
		END IF;
		
		UPDATE cuentas_bancarias SET saldo = saldo - par_saldo WHERE cuenta_id = par_cuenta_id_origen;
		UPDATE cuentas_bancarias SET saldo = saldo + par_saldo WHERE cuenta_id = par_cuenta_id_destino;
	END;
$$;

CALL transferir_cuenta_bancaria(10, 100.00, 1);

-- 5.Agregar una nueva transacción
CREATE OR REPLACE PROCEDURE nueva_transaccion(
	par_cuenta_id INTEGER,
	par_tipo_transaccion VARCHAR(20),
	par_monto DECIMAL (15,2)
)language plpgsql
as $$
	DECLARE
		var_existe_cuenta boolean;
		var_existe_saldo boolean;
	BEGIN
		SELECT EXISTS(SELECT 1 FROM cuentas_bancarias where cuenta_id = par_cuenta_id) INTO var_existe_cuenta;
		SELECT EXISTS(SELECT 1 FROM cuentas_bancarias where cuenta_id = par_cuenta_id AND saldo >= par_monto) 
			INTO var_existe_saldo;
		
		IF NOT var_existe_cuenta THEN
			RAISE EXCEPTION 'El id de la cuenta no es existe: %', par_cuenta_id;
		END IF;
		
		IF par_tipo_transaccion = 'depósito' THEN
			INSERT INTO transacciones (cuenta_id, tipo_transaccion, monto, descripcion)
				VALUES (par_cuenta_id, par_tipo_transaccion, par_monto, 'Depósito');
			UPDATE cuentas_bancarias SET saldo = saldo + par_monto WHERE cuenta_id = par_cuenta_id;
		END IF;
		
		IF par_tipo_transaccion = 'retiro' THEN
			IF NOT var_existe_saldo THEN
				RAISE EXCEPTION 'No cuenta con saldo suficiente para la transferiencia: %', par_monto;
			END IF;
			INSERT INTO transacciones (cuenta_id, tipo_transaccion, monto, descripcion)
				VALUES (par_cuenta_id, par_tipo_transaccion, par_monto, 'Retiro');
			UPDATE cuentas_bancarias SET saldo = saldo - par_monto WHERE cuenta_id = par_cuenta_id;
		END IF;
	END;
$$;

CALL nueva_transaccion(10, 'depósito', 100.00);
CALL nueva_transaccion(10, 'retiro', 50.00);

-- 6.Calcular el saldo total de todas las cuentas de un cliente
CREATE OR REPLACE PROCEDURE saldo_total(
	par_cliente_id INTEGER
)language plpgsql
as $$
	DECLARE
		var_existe_cliente boolean;
		var_saldo_total INTEGER;
	BEGIN
		SELECT EXISTS(SELECT 1 FROM clientes where cliente_id = par_cliente_id) INTO var_existe_cliente;
		
		IF NOT var_existe_cliente THEN
			RAISE EXCEPTION 'El id del cliente no es existe: %', par_cliente_id;
		END IF;
		
		SELECT SUM(saldo) INTO var_saldo_total FROM cuentas_bancarias 
		WHERE cliente_id = par_cliente_id AND estado = 'ACTIVO';
		
		RAISE NOTICE 'El saldo total del cliente: % es: %', par_cliente_id, var_saldo_total;
	END;
$$;

CALL saldo_total(1);

-- 7.Generar un reporte de transacciones para un rango de fechas
CREATE OR REPLACE PROCEDURE reporte_transacciones(
	par_fecha_inicio TIMESTAMP,
	par_fecha_fin TIMESTAMP
)language plpgsql
as $$
	DECLARE
		table_result RECORD;
	BEGIN
		FOR table_result IN
		SELECT transaccion_id, cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion
			FROM transacciones WHERE fecha_transaccion BETWEEN par_fecha_inicio AND par_fecha_fin
		LOOP
			RAISE NOTICE 'transaccion_id: %, cuenta_id: %, tipo_transaccion: %, monto: %, fecha_transaccion: %, descripcion: %'
			, table_result.transaccion_id, table_result.cuenta_id, table_result.tipo_transaccion, table_result.monto, 
			table_result.fecha_transaccion, table_result.descripcion;
		END LOOP;
	END;
$$;

CALL reporte_transacciones('2024-08-01', '2024-08-10');
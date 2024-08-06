--1. Crear una nueva cuenta bancaria
--Crea una nueva cuenta bancaria para un cliente, asignando un número de cuenta único y 
--estableciendo un saldo inicial.

create or replace procedure crear_cuenta_bancaria (
	id_cliente integer, 
	tipo_cuenta varchar(10),
	saldo_inicial numeric(15, 2),
    id_sucursal integer)
language plpgsql
as $$
    -- creacion de variables
	declare num_cuenta varchar(16);
	declare existe_cliente boolean;
	declare existe_cuenta boolean default '1';
 
    begin
	-- se valida cliente
	   if id_cliente = 0  then 
	       raise exception 'Debe ingresar el id del cliente';
       end if;
	
	-- se valida que el cliente exista		
	   select case when count(1) > 0 then '1' else '0' end into existe_cliente
       from clientes  where cliente_id = id_cliente ;
	   if not existe_cliente then 
	      RAISE EXCEPTION 'El id de cliente no esta registrado';
	   end if;
	
       --se asigna un núemro de cuenta aleatorio
	   while existe_cuenta = '1' loop
	    num_cuenta = substr(cast(random() as text), 3, 16);
        select case when count(1) > 0 then '1' else '0' end into existe_cuenta
          from cuentas_bancarias  where numero_cuenta = num_cuenta; 
       end loop;
	
    -- logica de la funcion
	   insert into cuentas_bancarias(cliente_id, numero_cuenta, tipo_cuenta, saldo, 
									 fecha_apertura, estado, sucursal_id)
	   values(id_cliente, num_cuenta, tipo_cuenta, saldo_inicial,
				current_timestamp, 'ACTIVA', id_sucursal);
    end;
$$; 


call crear_cuenta_bancaria(2, 'AHORRO', 120000000, 3);
select * from cuentas_bancarias;


--2.Actualizar la información del cliente
--Actualiza la información personal de un cliente, como dirección, teléfono y correo electrónico, 
--basado en el ID del cliente.

create or replace procedure actualizar_cliente (
	id_cliente integer, 
	direccion_ varchar(100),
	telefono_ varchar(20),
    email varchar(100))
language plpgsql
as $$
    -- creacion de variables
	declare existe_cliente boolean;
	declare email_correct integer;

    begin
	-- se valida cliente
	   if id_cliente = 0  then 
	       raise exception 'Debe ingresar el id del cliente';
       end if;
	
	-- se valida que el cliente exista		
	   select case when count(1) > 0 then '1' else '0' end into existe_cliente
       from clientes  where cliente_id = id_cliente ;
	   if not existe_cliente then 
	      RAISE EXCEPTION 'El id de cliente no esta registrado';
	   end if;
	   
	   	-- se valida EMAIL
	   if TRIM(email) = ''  then 
	       raise exception 'Debe ingresar correo electronico';
       end if;
	   
	   email_correct = POSITION('@' IN email);
	   
	   if email_correct = 0  then 
	       raise exception 'Debe ingresar un correo valido';
       end if;
	
    -- logica de la funcion
	   update  clientes set direccion = direccion_ , 
	                        telefono = telefono_,  
							correo_electronico = email
	   where cliente_id = id_cliente;

    end;
$$;

call actualizar_cliente(2, 'dirección en cuaquier lado', '3017657676', 'correoprueba@gmail.com');
select * from clientes;

--3.Eliminar una cuenta bancaria
--Elimina una cuenta bancaria específica del sistema, incluyendo la eliminación de todas las transacciones asociadas.

create or replace procedure eliminar_cuenta_bancaria (
	id_cuenta integer)
language plpgsql
as $$
    -- creacion de variables
	declare existe_cuenta boolean;

    begin
	-- se valida cliente
	   if id_cuenta = 0  then 
	       raise exception 'debe ingresar el id de cuenta a eliminar';
       end if;
	   
	   select case when count(1) > 0 then '1' else '0' end into existe_cuenta
	    from cuentas_bancarias 
	   where cuenta_id = id_cuenta;
	   
	   if not existe_cuenta  then 
	       raise exception 'Cuenta bancaria no existe';
       end if;
	   
    -- logica de la funcion
	   delete  from transacciones 
	   where cuenta_id = id_cuenta;
	   
	   delete  from prestamos 
	   where cuenta_id = id_cuenta;
	   
	   delete  from tarjetas_credito 
	   where cuenta_id = id_cuenta;
	   
	   delete  from cuentas_bancarias 
	   where cuenta_id = id_cuenta;
    end;
$$;

call eliminar_cuenta_bancaria(1);

--4.Transferir fondos entre cuentas
--Realiza una transferencia de fondos desde una cuenta a otra, asegurando que ambas 
--cuentas se actualicen correctamente y se registre la transacción.

create or replace procedure tranferir_saldo_cuentas (
	id_cuenta_origen integer, 
	id_cuenta_destino integer,
	valor_transferencia numeric(15, 2),
    concepto varchar(100))
language plpgsql
as $$
    -- creacion de variables
	declare existe_cuenta boolean;
 
    begin
	-- se valida cuentas
	   if id_cuenta_origen = 0  then 
	       raise exception 'Debe ingresar id de cuenta origen';
       end if;
	   
	   if id_cuenta_destino = 0  then 
	       raise exception 'Debe ingresar id de cuenta destino';
       end if;
	   
	   if valor_transferencia <= 0 then
	      raise exception 'Valor a trasnferir en cero o negativo';
	   end if;
	
       select case when count(1) > 0 then '1' else '0' end into existe_cuenta
         from cuentas_bancarias  where cuenta_id = id_cuenta_origen; 
		 
	   if not existe_cuenta  then
	      raise exception 'Cuenta origen no existe';
	   end if;
	   
	   select case when count(1) > 0 then '1' else '0' end into existe_cuenta
         from cuentas_bancarias  where cuenta_id = id_cuenta_destino; 
		 
	   if not existe_cuenta  then
	      raise exception 'Cuenta destino no existe';
	   end if;
	
    -- logica de la funcion
	   insert into transacciones(cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion) 
	   values(id_cuenta_origen, 'TRANSFERENCIA', valor_transferencia, current_timestamp, concepto);
	   
	   insert into transacciones(cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion) 
	   values(id_cuenta_destino, 'TRANSFERENCIA', valor_transferencia, current_timestamp, concepto);
	   
	   update cuentas_bancarias set saldo = saldo - valor_transferencia where cuenta_id = id_cuenta_origen; 
	   update cuentas_bancarias set saldo = saldo + valor_transferencia where cuenta_id = id_cuenta_destino; 
    end;
$$;

call tranferir_saldo_cuentas(2, 4, 1000, 'Tranferencia pago postre');


--5.Agregar una nueva transacción
--Registra una nueva transacción (depósito, retiro) en el sistema, actualizando el saldo de la cuenta asociada.

create or replace procedure registrar_transaccion(
	id_cuenta integer, 
	valor_transferencia numeric(15, 2),
	tipo_transaccion_ varchar(13),
    concepto varchar(100))
language plpgsql
as $$
    -- creacion de variables
	declare existe_cuenta boolean;
 
    begin
	-- se valida cuentas
	   if id_cuenta = 0  then 
	       raise exception 'Debe ingresar id de cuenta';
       end if;
	   
	   if valor_transferencia <= 0 then
	      raise exception 'Valor a trasnferir en cero o negativo';
	   end if;
	
       select case when count(1) > 0 then '1' else '0' end into existe_cuenta
         from cuentas_bancarias  where cuenta_id = id_cuenta; 
		 
	   if not existe_cuenta  then
	      raise exception 'Cuenta no existe';
	   end if;
	   
	   if tipo_transaccion_ not in('TRANSFERENCIA', 'DEPOSITO', 'RETIRO') then
	   	      raise exception 'tipo transacción no existe';
	   end if;
	
    -- logica de la funcion
	   insert into transacciones(cuenta_id, tipo_transaccion, monto, fecha_transaccion, descripcion) 
	   values(id_cuenta, tipo_transaccion_, valor_transferencia, current_timestamp, concepto);
	   
	   update cuentas_bancarias set saldo = saldo - valor_transferencia where cuenta_id = id_cuenta;  
    end;
$$;

call registrar_transaccion(2, 50000, 'TRANSFERENCIA', 'Pagho arriendo');


--6.Calcular el saldo total de todas las cuentas de un cliente
--Calcula el saldo total combinado de todas las cuentas bancarias pertenecientes a un cliente específico.

create or replace function calcular_saldo_total (id_cliente integer)
returns numeric(15,2)
language plpgsql
as $$
    -- creacion de variables
    declare saldo_total numeric(15, 2) default 0.00;
	DECLARE existe_cliente boolean;
 
    begin
	--
	-- se valida cliente
	   if id_cliente = 0  then 
	       raise exception 'Debe ingresar el id del cliente';
       end if;
	   
	   select case when count(1) > 0 then '1' else '0' end into existe_cliente
       from clientes  where cliente_id = id_cliente ;
	   if not existe_cliente then 
	      RAISE EXCEPTION 'El id de cliente no esta registrado';
	   end if;
	 
	
    -- logica de la funcion
       select sum(saldo)
	   into saldo_total
       from cuentas_bancarias 
	   where cliente_id = id_cliente and estado = 'ACTIVA';

    -- retorno la variable con el resultado
       return saldo_total;
    end;
$$; 

select calcular_saldo_total(1);


--7.Generar un reporte de transacciones para un rango de fechas
--Genera un reporte detallado de todas las transacciones realizadas en un rango de fechas específico.


-- se crea UDF que retorna una tabla
create or replace function calcular_saldo_total (fecha_inicial timestamp, fecha_final timestamp)
returns table(transaccion_id_ integer,
			 cuenta_id_ integer,
			 tipo_transaccion_ varchar,
			 monto_  numeric,
			 fecha_transaccion_ timestamp,
			 descripcion_  varchar) 
 language plpgsql
 as $$
    -- creacion de variables
    declare saldo_total numeric(15, 2) default 0.00;
 
    begin
    -- logica de la funcion
	   return query
       select *
       from transacciones 
	   where fecha_transaccion between fecha_inicial and fecha_final;
    end;
$$; 

select * from calcular_saldo_total('2021-01-01', '2024-12-12');
select * from transacciones;










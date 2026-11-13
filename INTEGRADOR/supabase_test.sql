-- Prueba de la regla de temperatura. Correr DESPUÉS de supabase.sql (SQL Editor o execute_sql).
-- Todo queda dentro de una transacción que se revierte: no deja datos.
begin;

do $$
declare
  n int;
  a record;
begin
  -- 25 -> sin alarma
  insert into public.telemetria(device, temperature, humidity) values ('TEST', 25, 50);
  select count(*) into n from public.alarmas where device = 'TEST';
  assert n = 0, format('25 no debe crear alarma (hay %s)', n);

  -- 30.0 -> sin alarma (umbral estricto)
  insert into public.telemetria(device, temperature, humidity) values ('TEST', 30.0, 50);
  select count(*) into n from public.alarmas where device = 'TEST';
  assert n = 0, format('30.0 no debe crear alarma (hay %s)', n);

  -- 35 -> alarma ACTIVE_UNACK
  insert into public.telemetria(device, temperature, humidity) values ('TEST', 35, 50);
  select count(*) into n from public.alarmas where device = 'TEST';
  assert n = 1, format('35 debe crear 1 alarma (hay %s)', n);
  select * into a from public.alarmas where device = 'TEST';
  assert a.status = 'ACTIVE_UNACK', format('status esperado ACTIVE_UNACK, fue %s', a.status);
  assert a.temperature = 35, 'temperature esperada 35';
  assert a.type = 'High Temperature Alarm' and a.severity = 'CRITICAL', 'type/severity incorrectos';

  -- 36 -> actualiza la misma alarma
  insert into public.telemetria(device, temperature, humidity) values ('TEST', 36, 50);
  select count(*) into n from public.alarmas where device = 'TEST';
  assert n = 1, format('36 debe actualizar, no crear (hay %s)', n);
  select * into a from public.alarmas where device = 'TEST';
  assert a.temperature = 36, 'temperature esperada 36';
  assert a.updated_at >= a.created_at, 'updated_at debe ser >= created_at';

  -- alarma limpiada -> nueva alarma
  update public.alarmas set status = 'CLEARED_UNACK' where device = 'TEST';
  insert into public.telemetria(device, temperature, humidity) values ('TEST', 35, 50);
  select count(*) into n from public.alarmas where device = 'TEST';
  assert n = 2, format('tras limpiar debe haber 2 alarmas (hay %s)', n);
end $$;

rollback;

-- Estación climática ESP32 -> Supabase. Pegar completo en SQL Editor > Run (idempotente).
-- Reemplaza a ThingsBoard: telemetria = Save Timeseries, alarmas = Alarms.

-- Save Timeseries
create table if not exists public.telemetria (
  id                 bigserial primary key,
  device             text not null default 'ESP32_Estacion_Climatica',
  temperature        double precision not null,
  humidity           double precision not null,
  air_quality        int,
  local_alarm_status boolean not null default false,
  rssi               int,
  created_at         timestamptz not null default now()
);

-- Alarmas (equivalente a Create Alarm de ThingsBoard)
create table if not exists public.alarmas (
  id          bigserial primary key,
  device      text not null,
  type        text not null,
  severity    text not null,
  status      text not null default 'ACTIVE_UNACK'
              check (status in ('ACTIVE_UNACK','ACTIVE_ACK','CLEARED_UNACK','CLEARED_ACK')),
  temperature double precision,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  ack_at      timestamptz,
  cleared_at  timestamptz
);

-- Rule engine: Script Filter (temperature > 30, estricto) -> Create Alarm / Update Alarm.
-- security definer: anon no tiene policy de insert en alarmas, solo la regla las crea.
create or replace function public.regla_temperatura()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_id bigint;
begin
  if new.temperature > 30 then                       -- Script Filter
    select id into v_id from public.alarmas
     where device = new.device and type = 'High Temperature Alarm' and status like 'ACTIVE%'
     order by id desc limit 1;
    if found then                                    -- ya activa: Update Alarm
      update public.alarmas set temperature = new.temperature, updated_at = now() where id = v_id;
    else                                             -- Create Alarm
      insert into public.alarmas(device, type, severity, status, temperature)
      values (new.device, 'High Temperature Alarm', 'CRITICAL', 'ACTIVE_UNACK', new.temperature);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists regla_temperatura on public.telemetria;
create trigger regla_temperatura
after insert on public.telemetria
for each row execute function public.regla_temperatura();

-- Sin login: la app y el ESP32 usan la publishable/anon key.
alter table public.telemetria enable row level security;
alter table public.alarmas enable row level security;

revoke all on public.telemetria, public.alarmas from anon, authenticated;
grant select, insert on public.telemetria to anon;
grant select on public.alarmas to anon;
revoke update on public.alarmas from anon;
-- Solo las columnas que usa la app (Reconocer/Borrar); type, severity y temperature quedan protegidas.
grant update (status, ack_at, cleared_at) on public.alarmas to anon;
grant usage on sequence public.telemetria_id_seq to anon;

drop policy if exists "anon_insert" on public.telemetria;
create policy "anon_insert" on public.telemetria for insert to anon with check (true);
drop policy if exists "anon_select" on public.telemetria;
create policy "anon_select" on public.telemetria for select to anon using (true);

drop policy if exists "anon_select" on public.alarmas;
create policy "anon_select" on public.alarmas for select to anon using (true);
drop policy if exists "anon_update" on public.alarmas;
create policy "anon_update" on public.alarmas for update to anon using (true) with check (true);

-- Realtime: agregar cada tabla solo si aún no está publicada.
do $$
declare t text;
begin
  foreach t in array array['telemetria','alarmas'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

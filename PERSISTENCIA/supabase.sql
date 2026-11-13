-- Pegar completo en Supabase > SQL Editor > Run

create table if not exists public.lecturas (
  id          uuid primary key,            -- generado en el dispositivo: evita duplicados
  sensor      text not null,
  temperatura double precision not null,
  humedad     double precision not null,
  es_alerta   boolean not null default false,
  estado      text not null default 'pendiente',
  nota        text not null default '',
  created_at  timestamptz not null,
  updated_at  timestamptz not null         -- marca de tiempo para Last-Write-Wins
);

-- Last-Write-Wins en el servidor:
--  * si llega una versión con updated_at MÁS VIEJO que la guardada, se conserva la guardada.
--  * si alguien edita desde el dashboard sin tocar updated_at, se pone now() automáticamente.
create or replace function public.lecturas_lww()
returns trigger language plpgsql as $$
begin
  if new.updated_at = old.updated_at then
    new.updated_at := now();
    return new;
  elsif new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end $$;

drop trigger if exists lecturas_lww on public.lecturas;
create trigger lecturas_lww
before update on public.lecturas
for each row execute function public.lecturas_lww();

-- Sin login: la app usa la publishable/anon key.
alter table public.lecturas enable row level security;
drop policy if exists "anon_all" on public.lecturas;
create policy "anon_all" on public.lecturas
  for all to anon using (true) with check (true);

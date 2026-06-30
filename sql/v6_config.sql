-- ============================================================
-- v6: Tabla de configuración del centro (datos empresa + operacional)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================
set search_path to bienestar;

create table if not exists config (
  id int primary key default 1,
  razon_social text default 'AIVIMED',
  rut text default '78.217.799-0',
  direccion text default 'Aníbal Pinto 531, Of. 65, Concepción',
  correo text default 'aivimed.salud@gmail.com',
  telefono text,
  instagram text,
  iva_pct numeric not null default 19,
  politica_cotizacion text,
  hora_apertura text default '09:30',
  hora_cierre text default '19:30',
  sab_apertura text default '10:00',
  sab_cierre text default '14:00',
  actualizado_en timestamptz default now(),
  constraint config_single check (id = 1)
);

insert into config (id) values (1) on conflict (id) do nothing;

alter table config enable row level security;
create policy "auth_full" on config
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Lectura pública para que reservar.html use los horarios y datos
create policy "public_read_config" on config for select using (true);

reset search_path;

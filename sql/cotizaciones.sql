-- ============================================================
-- Módulo de Cotizaciones
-- Ejecutar en el SQL Editor de Supabase (schema bienestar)
-- ============================================================
set search_path to bienestar;

create table cotizaciones (
  id uuid primary key default gen_random_uuid(),
  numero serial,
  paciente_id uuid not null references pacientes(id) on delete cascade,
  fecha timestamptz not null default now(),
  estado text not null default 'borrador' check (estado in ('borrador', 'enviada', 'aprobada', 'rechazada')),
  notas text,
  creado_en timestamptz not null default now()
);

create table cotizacion_items (
  id uuid primary key default gen_random_uuid(),
  cotizacion_id uuid not null references cotizaciones(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  descripcion text not null,
  cantidad numeric(12,2) not null default 1,
  precio_unitario numeric(12,2) not null default 0,
  orden integer not null default 0
);

create index idx_cotizaciones_paciente on cotizaciones (paciente_id);
create index idx_cotizacion_items_cotizacion on cotizacion_items (cotizacion_id);

alter table cotizaciones enable row level security;
alter table cotizacion_items enable row level security;

create policy "auth_full" on cotizaciones
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "auth_full" on cotizacion_items
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

reset search_path;

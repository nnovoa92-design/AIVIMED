-- ============================================================
-- Esquema: Centro de Bienestar y Salud Integral
-- Schema separado "bienestar" para convivir con otros proyectos
-- Ejecutar COMPLETO en el SQL Editor de Supabase
-- ============================================================

create extension if not exists "uuid-ossp";

-- Crear el schema y dar acceso a los roles de Supabase
create schema if not exists bienestar;
grant usage on schema bienestar to anon, authenticated, service_role;
grant all on all tables in schema bienestar to anon, authenticated, service_role;
alter default privileges in schema bienestar grant all on tables to anon, authenticated, service_role;
alter default privileges in schema bienestar grant all on sequences to anon, authenticated, service_role;

-- Exponer el schema en la API de PostgREST
-- (agregar "bienestar" a la lista de schemas expuestos)
notify pgrst, 'reload schema';

-- Cambiar al schema bienestar para crear las tablas
set search_path to bienestar;

-- ------------------------------------------------------------
-- Perfiles (roles de usuario vinculados a auth.users)
-- ------------------------------------------------------------
create table if not exists bienestar.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  rol text not null default 'recepcion' check (rol in ('admin', 'profesional', 'recepcion')),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Pacientes
-- ------------------------------------------------------------
create table if not exists bienestar.pacientes (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null,
  apellido text not null,
  dni text unique,
  fecha_nacimiento date,
  telefono text,
  email text,
  direccion text,
  contacto_emergencia_nombre text,
  contacto_emergencia_telefono text,
  antecedentes text,
  observaciones text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists idx_pacientes_apellido on bienestar.pacientes (apellido);
create index if not exists idx_pacientes_dni on bienestar.pacientes (dni);

-- ------------------------------------------------------------
-- Catálogo de servicios
-- ------------------------------------------------------------
create table if not exists bienestar.categorias_servicios (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null unique,
  descripcion text,
  orden integer not null default 0
);

create table if not exists bienestar.servicios (
  id uuid primary key default uuid_generate_v4(),
  categoria_id uuid references bienestar.categorias_servicios(id) on delete set null,
  nombre text not null,
  descripcion text,
  duracion_min integer,
  precio numeric(12,2),
  requiere_consentimiento boolean not null default false,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create index if not exists idx_servicios_categoria on bienestar.servicios (categoria_id);

-- ------------------------------------------------------------
-- Personal / Profesionales
-- ------------------------------------------------------------
create table if not exists bienestar.personal (
  id uuid primary key default uuid_generate_v4(),
  perfil_id uuid references bienestar.perfiles(id) on delete set null,
  nombre text not null,
  apellido text not null,
  especialidad text,
  matricula text,
  telefono text,
  email text,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create table if not exists bienestar.personal_servicios (
  personal_id uuid references bienestar.personal(id) on delete cascade,
  servicio_id uuid references bienestar.servicios(id) on delete cascade,
  primary key (personal_id, servicio_id)
);

-- ------------------------------------------------------------
-- Agenda / Turnos
-- ------------------------------------------------------------
create table if not exists bienestar.turnos (
  id uuid primary key default uuid_generate_v4(),
  paciente_id uuid not null references bienestar.pacientes(id) on delete cascade,
  servicio_id uuid references bienestar.servicios(id) on delete set null,
  personal_id uuid references bienestar.personal(id) on delete set null,
  fecha_hora timestamptz not null,
  duracion_min integer,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'confirmado', 'completado', 'cancelado', 'ausente')),
  notas text,
  creado_en timestamptz not null default now()
);

create index if not exists idx_turnos_fecha on bienestar.turnos (fecha_hora);
create index if not exists idx_turnos_paciente on bienestar.turnos (paciente_id);
create index if not exists idx_turnos_personal on bienestar.turnos (personal_id);

-- ------------------------------------------------------------
-- Sesiones / Fichas de tratamiento
-- ------------------------------------------------------------
create table if not exists bienestar.sesiones (
  id uuid primary key default uuid_generate_v4(),
  turno_id uuid references bienestar.turnos(id) on delete set null,
  paciente_id uuid not null references bienestar.pacientes(id) on delete cascade,
  servicio_id uuid references bienestar.servicios(id) on delete set null,
  personal_id uuid references bienestar.personal(id) on delete set null,
  fecha timestamptz not null default now(),
  detalle text,
  observaciones text,
  fotos jsonb,
  creado_en timestamptz not null default now()
);

create index if not exists idx_sesiones_paciente on bienestar.sesiones (paciente_id);
create index if not exists idx_sesiones_fecha on bienestar.sesiones (fecha);

-- ------------------------------------------------------------
-- Insumos / Stock
-- ------------------------------------------------------------
create table if not exists bienestar.insumos (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null,
  unidad text not null default 'unidad',
  stock_actual numeric(12,2) not null default 0,
  stock_minimo numeric(12,2) not null default 0,
  precio_unitario numeric(12,2),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create table if not exists bienestar.sesion_insumos (
  id uuid primary key default uuid_generate_v4(),
  sesion_id uuid not null references bienestar.sesiones(id) on delete cascade,
  insumo_id uuid not null references bienestar.insumos(id) on delete restrict,
  cantidad numeric(12,2) not null,
  lote text
);

create table if not exists bienestar.movimientos_stock (
  id uuid primary key default uuid_generate_v4(),
  insumo_id uuid not null references bienestar.insumos(id) on delete cascade,
  tipo text not null check (tipo in ('entrada', 'salida', 'ajuste')),
  cantidad numeric(12,2) not null,
  motivo text,
  sesion_id uuid references bienestar.sesiones(id) on delete set null,
  fecha timestamptz not null default now()
);

create index if not exists idx_movimientos_insumo on bienestar.movimientos_stock (insumo_id);

-- ------------------------------------------------------------
-- Pagos
-- ------------------------------------------------------------
create table if not exists bienestar.pagos (
  id uuid primary key default uuid_generate_v4(),
  paciente_id uuid not null references bienestar.pacientes(id) on delete cascade,
  turno_id uuid references bienestar.turnos(id) on delete set null,
  sesion_id uuid references bienestar.sesiones(id) on delete set null,
  monto numeric(12,2) not null,
  metodo_pago text check (metodo_pago in ('efectivo', 'tarjeta_debito', 'tarjeta_credito', 'transferencia', 'otro')),
  fecha timestamptz not null default now(),
  notas text
);

create index if not exists idx_pagos_paciente on bienestar.pagos (paciente_id);
create index if not exists idx_pagos_fecha on bienestar.pagos (fecha);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table bienestar.perfiles enable row level security;
alter table bienestar.pacientes enable row level security;
alter table bienestar.categorias_servicios enable row level security;
alter table bienestar.servicios enable row level security;
alter table bienestar.personal enable row level security;
alter table bienestar.personal_servicios enable row level security;
alter table bienestar.turnos enable row level security;
alter table bienestar.sesiones enable row level security;
alter table bienestar.insumos enable row level security;
alter table bienestar.sesion_insumos enable row level security;
alter table bienestar.movimientos_stock enable row level security;
alter table bienestar.pagos enable row level security;

do $$ declare t text; begin
  foreach t in array array['pacientes','categorias_servicios','servicios','personal',
    'personal_servicios','turnos','sesiones','insumos','sesion_insumos','movimientos_stock','pagos'] loop
    execute format(
      'create policy "auth_full" on bienestar.%I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'')', t
    );
  end loop;
end $$;

create policy "perfil_select" on bienestar.perfiles for select using (auth.uid() = id);
create policy "perfil_update" on bienestar.perfiles for update using (auth.uid() = id);

-- ============================================================
-- Datos iniciales: categorías y servicios precargados
-- ============================================================
insert into bienestar.categorias_servicios (nombre, orden) values
  ('Enfermería general', 1),
  ('Estética facial',    2),
  ('Estética corporal',  3),
  ('Vacunación',         4)
on conflict (nombre) do nothing;

insert into bienestar.servicios (categoria_id, nombre, requiere_consentimiento)
select c.id, s.nombre, s.requiere_consentimiento
from (values
  ('Enfermería general', 'Curaciones',                               false),
  ('Enfermería general', 'Inyectables',                              false),
  ('Enfermería general', 'Administración de medicamentos/vitaminas', false),
  ('Enfermería general', 'Sueroterapia',                             true),
  ('Enfermería general', 'Colocación de aros (adultos e infantes)',  true),
  ('Vacunación',         'Vacunación',                               false),
  ('Estética facial',    'Botox',                                    true),
  ('Estética facial',    'Ácido hialurónico',                        true),
  ('Estética facial',    'Rinomodelación',                           true),
  ('Estética facial',    'Limpieza facial',                          false),
  ('Estética facial',    'Bioestimuladores',                         true),
  ('Estética facial',    'Hilos revitalizantes',                     true),
  ('Estética facial',    'Mesoterapia facial',                       true),
  ('Estética corporal',  'Masajes reductores',                       false),
  ('Estética corporal',  'Depilación láser',                         false),
  ('Estética corporal',  'Hidrolipoclasia',                          true),
  ('Estética corporal',  'Radiofrecuencia',                          false),
  ('Estética corporal',  'Cavitación',                               false),
  ('Estética corporal',  'Mesoterapia corporal',                     true),
  ('Estética corporal',  'Tratamientos reductivos',                  false),
  ('Estética corporal',  'Lipolíticos',                              true),
  ('Estética corporal',  'Hilos tensores corporales',                true)
) as s(cat, nombre, requiere_consentimiento)
join bienestar.categorias_servicios c on c.nombre = s.cat
on conflict do nothing;

-- Restaurar search_path
reset search_path;

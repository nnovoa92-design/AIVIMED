-- ============================================================
-- v14: Atención domiciliaria y cuidados (curaciones, sondas, retiro de puntos,
--      ileostomía, administración de medicamentos, vacunación y cuidados generales).
--
-- Tablas nuevas (todas aisladas por clínica y SIN acceso público):
--   zonas_traslado        -> valor de traslado según la lejanía
--   tarifas_procedimiento -> valor de cada procedimiento
--   planes_cuidado        -> plan de un paciente (indicación médica, frecuencia, pagador...)
--   visitas_cuidado       -> cada visita (domicilio o clínica) con su registro clínico
--
-- Las fichas clínicas NO se borran: se anulan con motivo (anulada = true).
-- Todos los nombres van con el esquema "bienestar." para no depender del search_path.
-- IMPORTANTE: ejecutar el script COMPLETO (Ctrl+A antes de pegar; si hay texto
-- seleccionado, el editor corre solo la selección). Seguro de correr más de una vez.
-- ============================================================

-- 1) Zonas de traslado (el valor depende de la lejanía)
create table if not exists bienestar.zonas_traslado (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  nombre text not null,
  valor numeric(12,0) not null default 0,
  activo boolean not null default true,
  orden int not null default 0,
  creado_en timestamptz not null default now()
);

-- 2) Tarifa por procedimiento (código fijo definido por la aplicación)
create table if not exists bienestar.tarifas_procedimiento (
  organizacion_id uuid not null default bienestar.current_org(),
  codigo text not null,
  valor numeric(12,0) not null default 0,
  actualizado_en timestamptz not null default now(),
  primary key (organizacion_id, codigo)
);

-- 3) Plan de cuidado (varias visitas, o una sola)
create table if not exists bienestar.planes_cuidado (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  paciente_id uuid not null references bienestar.pacientes(id) on delete cascade,
  procedimientos text[] not null default '{}',
  lugar text not null default 'domicilio' check (lugar in ('domicilio', 'clinica')),
  direccion text,
  referencia_acceso text,
  zona_id uuid references bienestar.zonas_traslado(id) on delete set null,
  -- Indicación médica
  medico_indica text,
  fecha_indicacion date,
  vigencia_hasta date,
  indicacion text,
  -- Frecuencia
  frecuencia text not null default 'unica'
    check (frecuencia in ('unica', 'diaria', 'dia_por_medio', 'semanal', 'otra')),
  frecuencia_detalle text,
  visitas_total int,
  fecha_inicio date,
  -- Cuidador / familiar
  cuidador_nombre text,
  cuidador_telefono text,
  cuidador_parentesco text,
  -- Quién paga: el propio paciente o un tercero
  pagador_tipo text not null default 'paciente' check (pagador_tipo in ('paciente', 'tercero')),
  pagador_nombre text,
  pagador_rut text,
  pagador_telefono text,
  pagador_email text,
  personal_id uuid references bienestar.personal(id) on delete set null,
  estado text not null default 'activo' check (estado in ('activo', 'suspendido', 'finalizado')),
  notas text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index if not exists idx_planes_cuidado_org on bienestar.planes_cuidado (organizacion_id, estado);
create index if not exists idx_planes_cuidado_paciente on bienestar.planes_cuidado (paciente_id);

-- 4) Visita (con su registro clínico por procedimiento)
create table if not exists bienestar.visitas_cuidado (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  plan_id uuid references bienestar.planes_cuidado(id) on delete set null,   -- null = visita suelta
  paciente_id uuid not null references bienestar.pacientes(id) on delete cascade,
  turno_id uuid references bienestar.turnos(id) on delete set null,          -- reservado para integrar con la agenda
  personal_id uuid references bienestar.personal(id) on delete set null,
  fecha_hora timestamptz not null,
  lugar text not null default 'domicilio' check (lugar in ('domicilio', 'clinica')),
  direccion text,
  zona_id uuid references bienestar.zonas_traslado(id) on delete set null,
  estado text not null default 'programada' check (estado in ('programada', 'realizada', 'cancelada')),
  -- [{ "tipo": "curacion", "datos": { ... } }, ...]
  procedimientos jsonb not null default '[]'::jsonb,
  signos jsonb,                                  -- { pa, fc, temp, sat }
  observaciones text,
  indicaciones_cuidador text,
  recibe_nombre text,
  valor_procedimientos numeric(12,0) not null default 0,
  valor_traslado numeric(12,0) not null default 0,
  anulada boolean not null default false,
  motivo_anulacion text,
  anulada_en timestamptz,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index if not exists idx_visitas_cuidado_org_fecha on bienestar.visitas_cuidado (organizacion_id, fecha_hora desc);
create index if not exists idx_visitas_cuidado_plan on bienestar.visitas_cuidado (plan_id);
create index if not exists idx_visitas_cuidado_paciente on bienestar.visitas_cuidado (paciente_id);

-- 5) Seguridad: aislamiento por clínica y nada público
do $$
declare t text;
begin
  foreach t in array array['zonas_traslado', 'tarifas_procedimiento', 'planes_cuidado', 'visitas_cuidado'] loop
    execute format('alter table bienestar.%I enable row level security', t);
    execute format('drop policy if exists "org_isolation" on bienestar.%I', t);
    execute format('create policy "org_isolation" on bienestar.%I for all using (organizacion_id = bienestar.current_org()) with check (organizacion_id = bienestar.current_org())', t);
    execute format('revoke all on bienestar.%I from anon', t);
    execute format('grant select, insert, update, delete on bienestar.%I to authenticated', t);
  end loop;
end $$;

-- 6) Tarifas iniciales (en 0) para la clínica AIVIMED; el equipo las completa en la pantalla
insert into bienestar.tarifas_procedimiento (organizacion_id, codigo, valor)
select o.id, c.codigo, 0
from bienestar.organizaciones o
cross join (values ('curacion'), ('sonda'), ('retiro_puntos'), ('ileostomia'),
                   ('medicamentos'), ('vacunacion'), ('cuidados_generales')) as c(codigo)
where o.slug = 'aivimed'
on conflict do nothing;

notify pgrst, 'reload schema';

-- Verificación: debe mostrar 4 tablas
select 'v14 atencion domiciliaria aplicada' as estado,
       (select count(*) from information_schema.tables
         where table_schema = 'bienestar'
           and table_name in ('zonas_traslado', 'tarifas_procedimiento', 'planes_cuidado', 'visitas_cuidado')) as tablas_creadas;

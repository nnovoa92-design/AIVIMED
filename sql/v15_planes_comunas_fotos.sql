-- ============================================================
-- v15: Atención domiciliaria — comunas con KM, tipos de plan, procedimientos
--      propios y fotos de los procedimientos (almacenamiento PRIVADO).
--
--  1) zonas_traslado.km  → distancia en km (se muestra junto al nombre de la comuna)
--  2) tipos_plan         → catálogo de planes (en qué consiste, nº de sesiones, frecuencia)
--  3) procedimientos_extra → procedimientos que la clínica agrega a los 7 base
--  4) planes_cuidado     → guarda el tipo, el nombre y "en qué consiste"
--  5) Comunas de la Provincia de Concepción y tipos de plan iniciales (AIVIMED)
--  6) Bucket privado "cuidados" para las fotos, aislado por clínica
--
-- Todos los nombres van con "bienestar." (no depende del search_path).
-- Ejecutar el script COMPLETO (Ctrl+A antes de pegar). Seguro de correr más de una vez.
-- ============================================================

-- 1) Distancia en km de cada zona / comuna
alter table bienestar.zonas_traslado add column if not exists km numeric(6,1);

-- 2) Catálogo de tipos de plan
create table if not exists bienestar.tipos_plan (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  nombre text not null,
  descripcion text,
  procedimientos text[] not null default '{}',
  sesiones int,
  frecuencia text not null default 'otra'
    check (frecuencia in ('unica', 'diaria', 'dia_por_medio', 'semanal', 'otra')),
  activo boolean not null default true,
  orden int not null default 0,
  creado_en timestamptz not null default now()
);

-- 3) Procedimientos propios de la clínica (además de los 7 base)
create table if not exists bienestar.procedimientos_extra (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  codigo text not null,
  nombre text not null,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  unique (organizacion_id, codigo)
);

-- 4) El plan guarda su tipo, su nombre y en qué consiste
alter table bienestar.planes_cuidado
  add column if not exists tipo_plan_id uuid references bienestar.tipos_plan(id) on delete set null;
alter table bienestar.planes_cuidado add column if not exists nombre text;
alter table bienestar.planes_cuidado add column if not exists descripcion text;

-- Seguridad de las tablas nuevas: aislamiento por clínica y nada público
do $$
declare t text;
begin
  foreach t in array array['tipos_plan', 'procedimientos_extra'] loop
    execute format('alter table bienestar.%I enable row level security', t);
    execute format('drop policy if exists "org_isolation" on bienestar.%I', t);
    execute format('create policy "org_isolation" on bienestar.%I for all using (organizacion_id = bienestar.current_org()) with check (organizacion_id = bienestar.current_org())', t);
    execute format('revoke all on bienestar.%I from anon', t);
    execute format('grant select, insert, update, delete on bienestar.%I to authenticated', t);
  end loop;
end $$;

-- 5a) Comunas de la Provincia de Concepción, con distancia APROXIMADA por carretera
--     desde el centro de Concepción. Son referenciales: se corrigen en la pantalla.
--     El valor del traslado queda en 0 para que la clínica lo defina.
insert into bienestar.zonas_traslado (organizacion_id, nombre, km, valor, orden)
select o.id, c.nombre, c.km, 0, c.orden
from bienestar.organizaciones o
cross join (values
  ('Concepción (urbano)',     0, 1),
  ('Hualpén',                10, 2),
  ('San Pedro de la Paz',    10, 3),
  ('Chiguayante',            10, 4),
  ('Talcahuano',             15, 5),
  ('Penco',                  18, 6),
  ('Hualqui',                25, 7),
  ('Tomé',                   30, 8),
  ('Coronel',                30, 9),
  ('Florida',                30, 10),
  ('Lota',                   38, 11),
  ('Santa Juana',            42, 12)
) as c(nombre, km, orden)
where o.slug = 'aivimed'
  and not exists (
    select 1 from bienestar.zonas_traslado z
    where z.organizacion_id = o.id and lower(z.nombre) = lower(c.nombre)
  );

-- 5b) Tipos de plan iniciales (la clínica los edita o agrega los suyos)
insert into bienestar.tipos_plan (organizacion_id, nombre, descripcion, procedimientos, sesiones, frecuencia, orden)
select o.id, p.nombre, p.descripcion, p.procs, p.sesiones, p.frecuencia, p.orden
from bienestar.organizaciones o
cross join (values
  ('Curaciones',
   'Curaciones a domicilio o en la clínica según indicación médica.',
   array['curacion']::text[], null::int, 'diaria', 1),
  ('Control y cambio de sonda',
   'Control, lavado y cambio de sonda según indicación médica.',
   array['sonda']::text[], null::int, 'otra', 2),
  ('Administración de medicamentos',
   'Administración de medicamentos según receta o indicación médica.',
   array['medicamentos']::text[], null::int, 'diaria', 3),
  ('Retiro de puntos',
   'Retiro de puntos de sutura.',
   array['retiro_puntos']::text[], 1, 'unica', 4),
  ('Vacunación',
   'Aplicación de vacunas, con registro de lote y vencimiento.',
   array['vacunacion']::text[], 1, 'unica', 5),
  ('Cuidado de ileostomía',
   'Control del estoma y cambio de bolsa o placa.',
   array['ileostomia']::text[], null::int, 'otra', 6),
  ('Cuidados generales de enfermería',
   'Cuidados generales de enfermería a domicilio.',
   array['cuidados_generales']::text[], null::int, 'otra', 7)
) as p(nombre, descripcion, procs, sesiones, frecuencia, orden)
where o.slug = 'aivimed'
  and not exists (
    select 1 from bienestar.tipos_plan t
    where t.organizacion_id = o.id and lower(t.nombre) = lower(p.nombre)
  );

-- 6) Fotos de los procedimientos: bucket PRIVADO. Cada clínica solo ve su carpeta
--    (la primera parte de la ruta es el id de la clínica).
insert into storage.buckets (id, name, public)
values ('cuidados', 'cuidados', false)
on conflict (id) do nothing;

drop policy if exists "cuidados_select" on storage.objects;
create policy "cuidados_select" on storage.objects for select to authenticated
  using (bucket_id = 'cuidados' and (storage.foldername(name))[1] = bienestar.current_org()::text);

drop policy if exists "cuidados_insert" on storage.objects;
create policy "cuidados_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'cuidados' and (storage.foldername(name))[1] = bienestar.current_org()::text);

drop policy if exists "cuidados_update" on storage.objects;
create policy "cuidados_update" on storage.objects for update to authenticated
  using (bucket_id = 'cuidados' and (storage.foldername(name))[1] = bienestar.current_org()::text)
  with check (bucket_id = 'cuidados' and (storage.foldername(name))[1] = bienestar.current_org()::text);

drop policy if exists "cuidados_delete" on storage.objects;
create policy "cuidados_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'cuidados' and (storage.foldername(name))[1] = bienestar.current_org()::text);

notify pgrst, 'reload schema';

-- Verificación: debe mostrar tablas_nuevas = 2, comunas >= 12, tipos_plan >= 7, bucket_privado = true
select 'v15 planes, comunas y fotos aplicado' as estado,
       (select count(*) from information_schema.tables
         where table_schema = 'bienestar' and table_name in ('tipos_plan', 'procedimientos_extra')) as tablas_nuevas,
       (select count(*) from bienestar.zonas_traslado where km is not null) as comunas,
       (select count(*) from bienestar.tipos_plan) as tipos_plan,
       (select coalesce(bool_and(not public), false) from storage.buckets where id = 'cuidados') as bucket_privado;

-- ============================================================
-- v4: Tratamientos/Packs de sesiones + fotos por sesión
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================
set search_path to bienestar;

-- Tratamiento / Pack: agrupa N sesiones del mismo paciente y procedimiento
create table if not exists tratamientos (
  id uuid primary key default gen_random_uuid(),
  paciente_id uuid not null references pacientes(id) on delete cascade,
  servicio_id uuid references servicios(id) on delete set null,
  total_sesiones int not null default 1,
  notas text,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create index if not exists idx_tratamientos_paciente on tratamientos (paciente_id);

-- La sesión puede pertenecer a un pack y tener un número de sesión
alter table sesiones add column if not exists tratamiento_id uuid references tratamientos(id) on delete set null;
alter table sesiones add column if not exists numero_sesion int;

alter table tratamientos enable row level security;
create policy "auth_full" on tratamientos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

reset search_path;

-- ============================================================
-- Storage: bucket público para fotos de sesión
-- (los nombres de archivo son aleatorios e impredecibles)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('sesiones', 'sesiones', true)
on conflict (id) do nothing;

-- Lectura pública (URLs impredecibles); escritura/borrado solo autenticados
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sesiones_read') then
    create policy "sesiones_read" on storage.objects for select using (bucket_id = 'sesiones');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sesiones_insert') then
    create policy "sesiones_insert" on storage.objects for insert to authenticated with check (bucket_id = 'sesiones');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sesiones_delete') then
    create policy "sesiones_delete" on storage.objects for delete to authenticated using (bucket_id = 'sesiones');
  end if;
end $$;

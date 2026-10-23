-- ============================================================
-- v17: Adjuntos del Detalle de atención (receta, orden médica, foto de la boleta física…).
--
-- Van en una tabla aparte para poder adjuntar también después de emitir el detalle,
-- sin modificar el documento (que queda bloqueado). Los archivos se guardan en el
-- bucket PRIVADO "cuidados" (creado en v15), en la carpeta <clinica>/detalles/<detalle>/.
-- Requiere v15 y v16. Seguro de correr más de una vez.
-- ============================================================

create table if not exists bienestar.detalle_adjuntos (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  detalle_id uuid not null references bienestar.detalles_atencion(id) on delete cascade,
  path text not null,
  etiqueta text not null default 'Adjunto',
  tipo text,                                   -- image/jpeg o application/pdf
  nombre_original text,
  creado_por uuid default auth.uid(),
  creado_en timestamptz not null default now()
);
create index if not exists idx_detalle_adjuntos_detalle on bienestar.detalle_adjuntos (detalle_id);

alter table bienestar.detalle_adjuntos enable row level security;
drop policy if exists "org_isolation" on bienestar.detalle_adjuntos;
create policy "org_isolation" on bienestar.detalle_adjuntos for all
  using (organizacion_id = bienestar.current_org()) with check (organizacion_id = bienestar.current_org());
revoke all on bienestar.detalle_adjuntos from anon;
grant select, insert, update, delete on bienestar.detalle_adjuntos to authenticated;

notify pgrst, 'reload schema';

-- Verificación: debe mostrar tabla_creada = 1 y bucket_existe = true
select 'v17 adjuntos del detalle aplicado' as estado,
       (select count(*) from information_schema.tables
         where table_schema = 'bienestar' and table_name = 'detalle_adjuntos') as tabla_creada,
       exists (select 1 from storage.buckets where id = 'cuidados') as bucket_existe;

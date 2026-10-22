-- ============================================================
-- v16: Detalle de atención (cuenta de atención para reembolsos u otros trámites).
--
-- NO es boleta ni factura, no tiene validez tributaria y NO cuenta en los pagos ni en
-- los reportes: vive en su propia tabla. Un detalle por atención, con número correlativo
-- propio de la clínica (DA-0001), previsión (FONASA o ISAPRE y cuál), indicación médica,
-- quién paga y, si existe, los datos de la boleta física.
--
-- Estados: borrador (editable) → emitido (bloqueado) → anulado (con motivo).
-- Un detalle emitido NO se modifica ni se borra: se anula y se crea uno nuevo.
--
-- Todos los nombres van con "bienestar." (no depende del search_path).
-- Ejecutar el script COMPLETO (Ctrl+A antes de pegar). Seguro de correr más de una vez.
-- ============================================================

create table if not exists bienestar.detalles_atencion (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default bienestar.current_org(),
  numero int not null,                                   -- correlativo por clínica (lo asigna un trigger)
  paciente_id uuid not null references bienestar.pacientes(id) on delete restrict,
  visita_id uuid references bienestar.visitas_cuidado(id) on delete set null,   -- atención de origen (opcional)
  turno_id uuid references bienestar.turnos(id) on delete set null,             -- atención de origen (opcional)
  fecha date not null default current_date,
  estado text not null default 'borrador' check (estado in ('borrador', 'emitido', 'anulado')),
  -- [{ fecha, descripcion, profesional, lugar, cantidad, valor_unitario }]
  items jsonb not null default '[]'::jsonb,
  iva_modo text not null default 'incluido' check (iva_modo in ('incluido', 'mas_iva', 'sin_iva')),
  iva_pct numeric(5,2) not null default 19,
  neto numeric(12,0) not null default 0,
  iva numeric(12,0) not null default 0,
  total numeric(12,0) not null default 0,
  prevision text check (prevision in ('fonasa', 'isapre')),
  isapre_nombre text,
  medico_indica text,
  indicacion text,
  pagador_nombre text,
  pagador_rut text,
  boleta_numero text,
  boleta_fecha date,
  boleta_monto numeric(12,0),
  notas text,
  creado_por uuid default auth.uid(),
  emitido_en timestamptz,
  emitido_por uuid,
  anulado_en timestamptz,
  motivo_anulacion text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (organizacion_id, numero)
);
create index if not exists idx_detalles_atencion_org_fecha on bienestar.detalles_atencion (organizacion_id, fecha desc);
create index if not exists idx_detalles_atencion_paciente on bienestar.detalles_atencion (paciente_id);

-- Número correlativo por clínica (DA-0001, DA-0002…), sin saltos ni repetidos aunque dos personas emitan a la vez
create or replace function bienestar.detalle_asignar_numero() returns trigger
language plpgsql security definer set search_path = bienestar as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('detalle_atencion:' || new.organizacion_id::text, 0));
  select coalesce(max(d.numero), 0) + 1 into new.numero
  from bienestar.detalles_atencion d where d.organizacion_id = new.organizacion_id;
  return new;
end $$;

drop trigger if exists trg_detalle_numero on bienestar.detalles_atencion;
create trigger trg_detalle_numero before insert on bienestar.detalles_atencion
  for each row execute function bienestar.detalle_asignar_numero();

-- Protección: lo emitido no se toca; solo se puede anular (cambiando únicamente los campos de anulación)
create or replace function bienestar.detalle_proteger() returns trigger
language plpgsql security definer set search_path = bienestar as $$
declare quitar text[] := array['estado', 'anulado_en', 'motivo_anulacion', 'actualizado_en'];
begin
  if old.estado = 'anulado' then
    raise exception 'Un detalle anulado no se puede modificar.';
  end if;
  if old.estado = 'emitido' then
    if new.estado <> 'anulado' then
      raise exception 'Un detalle emitido no se puede modificar: anúlalo y crea uno nuevo.';
    end if;
    if coalesce(btrim(new.motivo_anulacion), '') = '' then
      raise exception 'Indica el motivo de la anulación.';
    end if;
    if (to_jsonb(new) - quitar) is distinct from (to_jsonb(old) - quitar) then
      raise exception 'Al anular no se pueden cambiar otros datos.';
    end if;
    new.anulado_en := coalesce(new.anulado_en, now());
  elsif old.estado = 'borrador' and new.estado = 'emitido' then
    new.emitido_en := now();
    new.emitido_por := auth.uid();
  end if;
  return new;
end $$;

drop trigger if exists trg_detalle_proteger on bienestar.detalles_atencion;
create trigger trg_detalle_proteger before update on bienestar.detalles_atencion
  for each row execute function bienestar.detalle_proteger();

create or replace function bienestar.detalle_no_borrar() returns trigger
language plpgsql security definer set search_path = bienestar as $$
begin
  if old.estado <> 'borrador' then
    raise exception 'Un detalle emitido o anulado no se borra (queda registrado).';
  end if;
  return old;
end $$;

drop trigger if exists trg_detalle_no_borrar on bienestar.detalles_atencion;
create trigger trg_detalle_no_borrar before delete on bienestar.detalles_atencion
  for each row execute function bienestar.detalle_no_borrar();

-- Seguridad: aislamiento por clínica y nada público
alter table bienestar.detalles_atencion enable row level security;
drop policy if exists "org_isolation" on bienestar.detalles_atencion;
create policy "org_isolation" on bienestar.detalles_atencion for all
  using (organizacion_id = bienestar.current_org()) with check (organizacion_id = bienestar.current_org());
revoke all on bienestar.detalles_atencion from anon;
grant select, insert, update, delete on bienestar.detalles_atencion to authenticated;

notify pgrst, 'reload schema';

-- Verificación: debe mostrar tabla_creada = 1 y triggers = 3
select 'v16 detalle de atencion aplicado' as estado,
       (select count(*) from information_schema.tables
         where table_schema = 'bienestar' and table_name = 'detalles_atencion') as tabla_creada,
       (select count(*) from pg_trigger
         where tgrelid = 'bienestar.detalles_atencion'::regclass and not tgisinternal) as triggers;

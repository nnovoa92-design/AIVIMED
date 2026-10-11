-- ============================================================
-- v10: Campanita de novedades (notificaciones automáticas).
-- Se crean solas cuando el PACIENTE actúa desde un link público:
--   · reserva online nueva (turnos con origen = 'online')
--   · cotización aceptada / rechazada (respuesta.html)
--   · consentimiento firmado a distancia (firmar-consentimiento.html)
-- Lo que hace el propio equipo con sesión iniciada no avisa.
-- Un fallo al crear el aviso NUNCA bloquea la acción del paciente.
-- Aislado por clínica. Seguro de correr más de una vez.
-- ============================================================
set search_path to bienestar;

create table if not exists notificaciones (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default current_org(),
  tipo text not null,
  titulo text not null,
  detalle text,
  url text,                                  -- pantalla a abrir, ej. 'agenda.html'
  leida boolean not null default false,
  creado_en timestamptz not null default now()
);
create index if not exists idx_notificaciones_org on notificaciones (organizacion_id, leida, creado_en desc);

alter table notificaciones enable row level security;
drop policy if exists "org_isolation" on notificaciones;
create policy "org_isolation" on notificaciones for all
  using (organizacion_id = current_org()) with check (organizacion_id = current_org());

-- El público (anon) nunca toca esta tabla; solo el equipo con sesión.
revoke all on notificaciones from anon;
grant select, insert, update, delete on notificaciones to authenticated;

-- ¿La acción la hizo alguien con sesión en el sistema (la clínica)? Entonces no se avisa.
create or replace function notif_es_clinica() returns boolean
language plpgsql stable as $$
declare v_rol text;
begin
  begin
    v_rol := coalesce(nullif(current_setting('request.jwt.claims', true), '')::json ->> 'role', '');
  exception when others then v_rol := '';
  end;
  return v_rol = 'authenticated';
end $$;

-- Reserva online nueva
create or replace function notif_turno_online() returns trigger
language plpgsql security definer set search_path = bienestar as $$
declare v_pac text; v_srv text;
begin
  begin
    select trim(nombre || ' ' || coalesce(apellido, '')) into v_pac from pacientes where id = new.paciente_id;
    select nombre into v_srv from servicios where id = new.servicio_id;
    insert into notificaciones (organizacion_id, tipo, titulo, detalle, url)
    values (new.organizacion_id, 'reserva_online', 'Nueva reserva online',
      coalesce(nullif(v_pac, ''), 'Paciente') || ' · ' || coalesce(v_srv, 'Servicio')
        || ' · ' || to_char(new.fecha_hora at time zone 'America/Santiago', 'DD-MM HH24:MI'),
      'agenda.html');
  exception when others then null;   -- un fallo al avisar nunca debe impedir la reserva
  end;
  return new;
end $$;

drop trigger if exists trg_notif_turno_online on turnos;
create trigger trg_notif_turno_online after insert on turnos
  for each row when (new.origen = 'online') execute function notif_turno_online();

-- Cotización aceptada / rechazada por el paciente
create or replace function notif_cotizacion_respuesta() returns trigger
language plpgsql security definer set search_path = bienestar as $$
declare v_pac text;
begin
  begin
    if notif_es_clinica() then return new; end if;
    select trim(nombre || ' ' || coalesce(apellido, '')) into v_pac from pacientes where id = new.paciente_id;
    insert into notificaciones (organizacion_id, tipo, titulo, detalle, url)
    values (new.organizacion_id,
      case when new.estado = 'aprobada' then 'cotizacion_aprobada' else 'cotizacion_rechazada' end,
      'Cotización COT-' || lpad(new.numero::text, 4, '0')
        || case when new.estado = 'aprobada' then ' aceptada por el paciente' else ' rechazada por el paciente' end,
      coalesce(nullif(v_pac, ''), 'Paciente'),
      'cotizaciones.html');
  exception when others then null;
  end;
  return new;
end $$;

drop trigger if exists trg_notif_cotizacion_respuesta on cotizaciones;
create trigger trg_notif_cotizacion_respuesta after update of estado on cotizaciones
  for each row when (new.estado in ('aprobada', 'rechazada') and old.estado is distinct from new.estado)
  execute function notif_cotizacion_respuesta();

-- Consentimiento firmado a distancia
create or replace function notif_consentimiento_firmado() returns trigger
language plpgsql security definer set search_path = bienestar as $$
declare v_pac text; v_srv text;
begin
  begin
    if notif_es_clinica() then return new; end if;
    select trim(nombre || ' ' || coalesce(apellido, '')) into v_pac from pacientes where id = new.paciente_id;
    select nombre into v_srv from servicios where id = new.servicio_id;
    insert into notificaciones (organizacion_id, tipo, titulo, detalle, url)
    values (new.organizacion_id, 'consentimiento_firmado', 'Consentimiento firmado',
      coalesce(nullif(v_pac, ''), 'Paciente') || coalesce(' · ' || v_srv, ''),
      'consentimientos.html');
  exception when others then null;
  end;
  return new;
end $$;

drop trigger if exists trg_notif_consentimiento_firmado on consentimientos;
create trigger trg_notif_consentimiento_firmado after update of firmado on consentimientos
  for each row when (new.firmado is true and old.firmado is distinct from new.firmado)
  execute function notif_consentimiento_firmado();

notify pgrst, 'reload schema';
select 'v10 notificaciones aplicado' as estado;
reset search_path;

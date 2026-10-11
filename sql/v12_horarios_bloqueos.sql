-- ============================================================
-- v12: Horario por día (lunes a domingo), bloqueos de agenda y
--      validación en el servidor de la reserva online.
-- Requiere v9, v10, v11 y saas/06. Seguro de correr más de una vez.
-- ============================================================
set search_path to bienestar;

-- 1) Horario por día de la semana (0 = domingo … 6 = sábado)
--    Formato: {"1": {"abierto": true, "desde": "09:30", "hasta": "19:30"}, ...}
--    Si una clínica aún no lo define, se deriva de las columnas antiguas
--    (hora_apertura/hora_cierre para lunes a viernes, sab_* para sábado, domingo cerrado).
alter table config add column if not exists horario_semana jsonb;

-- 2) Bloqueos de agenda (una hora, un día, una semana o cualquier rango)
create table if not exists bloqueos_agenda (
  id uuid primary key default gen_random_uuid(),
  organizacion_id uuid not null default current_org(),
  desde timestamptz not null,
  hasta timestamptz not null,
  motivo text,
  creado_en timestamptz not null default now(),
  constraint bloqueos_agenda_rango check (hasta > desde)
);
create index if not exists idx_bloqueos_agenda_org on bloqueos_agenda (organizacion_id, desde, hasta);

alter table bloqueos_agenda enable row level security;
drop policy if exists "org_isolation" on bloqueos_agenda;
create policy "org_isolation" on bloqueos_agenda for all
  using (organizacion_id = current_org()) with check (organizacion_id = current_org());
revoke all on bloqueos_agenda from anon;
grant select, insert, update, delete on bloqueos_agenda to authenticated;

-- 3) Horario normalizado de una clínica: siempre devuelve los 7 días
create or replace function horario_clinica(p_org uuid) returns jsonb
language plpgsql stable security definer set search_path = bienestar as $$
declare c record; v jsonb; r jsonb := '{}'::jsonb; i int;
begin
  select hora_apertura, hora_cierre, sab_apertura, sab_cierre, horario_semana into c
  from config where organizacion_id = p_org;
  v := c.horario_semana;
  for i in 0..6 loop
    if v is not null and jsonb_typeof(v -> i::text) = 'object' then
      r := r || jsonb_build_object(i::text, v -> i::text);
    elsif i = 0 then
      r := r || jsonb_build_object('0', jsonb_build_object('abierto', false, 'desde', '10:00', 'hasta', '14:00'));
    elsif i = 6 then
      r := r || jsonb_build_object('6', jsonb_build_object('abierto', true,
              'desde', coalesce(c.sab_apertura, '10:00'), 'hasta', coalesce(c.sab_cierre, '14:00')));
    else
      r := r || jsonb_build_object(i::text, jsonb_build_object('abierto', true,
              'desde', coalesce(c.hora_apertura, '09:30'), 'hasta', coalesce(c.hora_cierre, '19:30')));
    end if;
  end loop;
  return r;
end $$;
revoke execute on function horario_clinica(uuid) from public, anon;

-- 4) Datos de la página de reserva: ahora incluye el horario por día
create or replace function datos_reserva_publica(p_slug text)
returns json language plpgsql stable security definer set search_path = bienestar as $$
declare v_org uuid; v_nombre text;
begin
  select id, nombre into v_org, v_nombre from organizaciones where slug = p_slug and activo = true;
  if v_org is null then return null; end if;

  return json_build_object(
    'org', json_build_object('id', v_org, 'nombre', v_nombre),
    'config', (
      select json_build_object(
        'hora_apertura', hora_apertura, 'hora_cierre', hora_cierre,
        'sab_apertura', sab_apertura, 'sab_cierre', sab_cierre,
        'telefono', telefono, 'correo', correo,
        'direccion', direccion, 'razon_social', coalesce(razon_social, v_nombre),
        'horario_semana', horario_clinica(v_org)
      ) from config where organizacion_id = v_org
    ),
    'horario_semana', horario_clinica(v_org),
    'categorias', coalesce((
      select json_agg(json_build_object('id', id, 'nombre', nombre, 'orden', orden) order by orden)
      from categorias_servicios where organizacion_id = v_org
    ), '[]'::json),
    'servicios', coalesce((
      select json_agg(json_build_object(
        'id', id, 'nombre', nombre, 'descripcion', descripcion, 'precio', precio,
        'duracion_min', duracion_min, 'categoria_id', categoria_id,
        'requiere_consentimiento', requiere_consentimiento
      ) order by nombre)
      from servicios where organizacion_id = v_org and activo = true
    ), '[]'::json)
  );
end $$;
grant execute on function datos_reserva_publica(text) to anon, authenticated;

-- 5) Ocupación para la reserva pública: SOLO intervalos (turnos con su duración + bloqueos),
--    sin ningún dato de pacientes.
create or replace function ocupacion_publica(p_org uuid, p_desde timestamptz, p_hasta timestamptz)
returns jsonb language sql stable security definer set search_path = bienestar as $$
  select coalesce(jsonb_agg(jsonb_build_object('desde', x.d, 'hasta', x.h)), '[]'::jsonb)
  from (
    select t.fecha_hora as d,
           t.fecha_hora + make_interval(mins => greatest(coalesce(t.duracion_min, 60), 30)) as h
    from turnos t
    where t.organizacion_id = p_org and t.estado <> 'cancelado'
      and t.fecha_hora < p_hasta
      and t.fecha_hora + make_interval(mins => greatest(coalesce(t.duracion_min, 60), 30)) > p_desde
    union all
    select b.desde, b.hasta
    from bloqueos_agenda b
    where b.organizacion_id = p_org and b.desde < p_hasta and b.hasta > p_desde
  ) x;
$$;
grant execute on function ocupacion_publica(uuid, timestamptz, timestamptz) to anon, authenticated;

-- 6) Reserva por RUT con validación en el servidor: día/horario abierto, bloqueos y choques.
--    Reserva provisoriamente la duración del servicio redondeada a horas completas;
--    la clínica confirma las horas definitivas al confirmar el turno.
create or replace function crear_reserva_v2(
  p_slug text, p_nombre text, p_apellido text, p_dni text, p_telefono text,
  p_email text, p_servicio_id uuid, p_fecha_hora timestamptz, p_notas text default null)
returns json language plpgsql security definer set search_path = bienestar as $$
declare
  v_org uuid; v_pac uuid; v_dur int; v_bloq int;
  v_rut text := rut_formato_cl(p_dni);
  v_norm text := upper(regexp_replace(coalesce(p_dni, ''), '[^0-9kK]', '', 'g'));
  v_tel text := nullif(trim(coalesce(p_telefono, '')), '');
  v_pac_tel text;
  v_loc timestamp; v_dia jsonb; v_fin timestamptz;
  v_nom text; v_ape text;
begin
  select id into v_org from organizaciones where slug = p_slug and activo = true;
  if v_org is null then raise exception 'Clínica no disponible'; end if;

  select duracion_min into v_dur from servicios
  where id = p_servicio_id and organizacion_id = v_org and activo = true;
  if not found then raise exception 'Servicio no válido para esta clínica'; end if;

  if coalesce(btrim(p_dni), '') <> '' and v_rut is null then raise exception 'El RUT no es válido'; end if;
  if p_fecha_hora is null or p_fecha_hora < now() - interval '1 hour' then raise exception 'Fecha u hora inválidas'; end if;

  -- Un solo reservante a la vez por clínica y día (evita que dos personas tomen la misma hora)
  v_loc := p_fecha_hora at time zone 'America/Santiago';
  perform pg_advisory_xact_lock(hashtextextended(v_org::text || to_char(v_loc, 'YYYY-MM-DD'), 0));

  -- ¿La clínica atiende ese día y a esa hora?
  v_dia := horario_clinica(v_org) -> (extract(dow from v_loc)::int)::text;
  if v_dia is null or not coalesce((v_dia ->> 'abierto')::boolean, false) then
    raise exception 'La clínica no atiende ese día';
  end if;
  if v_loc::time < (v_dia ->> 'desde')::time or v_loc::time >= (v_dia ->> 'hasta')::time then
    raise exception 'Esa hora está fuera del horario de atención';
  end if;

  -- Tiempo que se reserva: duración del servicio en horas completas (mínimo 1 hora)
  v_bloq := greatest(60, (ceil(coalesce(v_dur, 60) / 60.0))::int * 60);
  v_fin := p_fecha_hora + make_interval(mins => v_bloq);

  if exists (select 1 from bloqueos_agenda b
             where b.organizacion_id = v_org and b.desde < v_fin and b.hasta > p_fecha_hora) then
    raise exception 'Ese horario no está disponible';
  end if;
  if exists (select 1 from turnos t
             where t.organizacion_id = v_org and t.estado <> 'cancelado'
               and t.fecha_hora < v_fin
               and t.fecha_hora + make_interval(mins => greatest(coalesce(t.duracion_min, 60), 30)) > p_fecha_hora) then
    raise exception 'Ese horario ya no está disponible';
  end if;

  -- Paciente por RUT
  if v_rut is not null then
    select id, telefono into v_pac, v_pac_tel from pacientes
    where organizacion_id = v_org and upper(regexp_replace(coalesce(dni, ''), '[^0-9kK]', '', 'g')) = v_norm
    order by activo desc, creado_en limit 1;
  end if;

  -- Sin teléfono en la solicitud: se usa el del paciente reconocido
  if v_tel is null then v_tel := nullif(trim(coalesce(v_pac_tel, '')), ''); end if;
  if v_tel is null then raise exception 'Faltan datos de contacto'; end if;

  -- Si no estaba por RUT: por teléfono (y se le completa el RUT si no tenía)
  if v_pac is null then
    select id into v_pac from pacientes where organizacion_id = v_org and telefono = v_tel limit 1;
    if v_pac is not null and v_rut is not null then
      update pacientes set dni = v_rut where id = v_pac and (dni is null or btrim(dni) = '');
    end if;
  end if;

  if v_pac is null then
    -- Lo que escribe un visitante se limpia de <, >, & y comillas (se muestra en pantallas del equipo)
    v_nom := left(trim(regexp_replace(coalesce(p_nombre, ''),   '[<>&"]', '', 'g')), 80);
    v_ape := left(trim(regexp_replace(coalesce(p_apellido, ''), '[<>&"]', '', 'g')), 80);
    if v_nom = '' or v_ape = '' then
      raise exception 'Faltan nombre y apellido';
    end if;
    insert into pacientes (organizacion_id, nombre, apellido, dni, telefono, email)
    values (v_org, v_nom, v_ape, v_rut, v_tel,
            nullif(left(trim(regexp_replace(coalesce(p_email, ''), '[<>&"]', '', 'g')), 120), ''))
    returning id into v_pac;
  end if;

  insert into turnos (organizacion_id, paciente_id, servicio_id, fecha_hora, duracion_min, estado, origen, notas)
  values (v_org, v_pac, p_servicio_id, p_fecha_hora, v_bloq, 'pendiente', 'online',
          nullif(left(regexp_replace(coalesce(p_notas, ''), '[<>&"]', '', 'g'), 500), ''));

  return json_build_object('ok', true);
end $$;
grant execute on function crear_reserva_v2(text, text, text, text, text, text, uuid, timestamptz, text) to anon, authenticated;

notify pgrst, 'reload schema';
select 'v12 horarios y bloqueos aplicado' as estado;
reset search_path;

-- ============================================================
-- v11: Reserva online que reconoce a la paciente por RUT.
-- Requiere haber corrido antes v9 (RUT único por clínica) y saas/06.
-- La función pública devuelve SOLO lo mínimo (primer nombre y 4 últimos dígitos
-- del teléfono) y limita las consultas por IP. Seguro de correr más de una vez.
-- ============================================================
set search_path to bienestar;

-- Registro de consultas por IP (solo lo usa la función; nadie lo lee desde la app)
create table if not exists reservar_consultas_rut (
  id bigserial primary key,
  ip text not null,
  creado_en timestamptz not null default now()
);
create index if not exists idx_reservar_consultas_rut on reservar_consultas_rut (ip, creado_en);
alter table reservar_consultas_rut enable row level security;   -- sin políticas
revoke all on reservar_consultas_rut from anon, authenticated;

-- RUT válido (dígito verificador) -> "12.345.678-5"; si no es válido, null
create or replace function rut_formato_cl(p text) returns text
language plpgsql immutable as $$
declare v text; cuerpo text; dv text; suma int := 0; mul int := 2; i int; r int; esperado text;
begin
  if p is null then return null; end if;
  v := upper(regexp_replace(p, '[^0-9kK]', '', 'g'));
  if v !~ '^[0-9]{6,8}[0-9K]$' then return null; end if;
  cuerpo := left(v, length(v) - 1);
  dv := right(v, 1);
  for i in reverse length(cuerpo)..1 loop
    suma := suma + substr(cuerpo, i, 1)::int * mul;
    mul := case when mul = 7 then 2 else mul + 1 end;
  end loop;
  r := 11 - (suma % 11);
  esperado := case when r = 11 then '0' when r = 10 then 'K' else r::text end;
  if dv <> esperado then return null; end if;
  return replace(to_char(cuerpo::bigint, 'FM999,999,999'), ',', '.') || '-' || dv;
end $$;

-- ¿Quién es? Devuelve lo mínimo (primer nombre y 4 últimos dígitos del teléfono)
create or replace function reservar_reconocer(p_slug text, p_rut text) returns jsonb
language plpgsql security definer set search_path = bienestar as $$
declare
  v_org uuid;
  v_norm text := upper(regexp_replace(coalesce(p_rut, ''), '[^0-9kK]', '', 'g'));
  v_h jsonb; v_ip text; v_n int; v_pac record; v_dig text;
begin
  select id into v_org from organizaciones where slug = p_slug and activo = true;
  if v_org is null then return jsonb_build_object('encontrado', false); end if;
  if rut_formato_cl(p_rut) is null then return jsonb_build_object('encontrado', false, 'invalido', true); end if;

  -- Límite de consultas por IP (20 cada 10 minutos)
  begin
    v_h := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then v_h := null;
  end;
  v_ip := coalesce(nullif(trim(split_part(coalesce(v_h ->> 'x-forwarded-for', v_h ->> 'cf-connecting-ip', ''), ',', 1)), ''), 'desconocido');
  delete from reservar_consultas_rut where creado_en < now() - interval '1 hour';
  select count(*) into v_n from reservar_consultas_rut where ip = v_ip and creado_en > now() - interval '10 minutes';
  if v_n >= 20 then return jsonb_build_object('encontrado', false, 'limite', true); end if;
  insert into reservar_consultas_rut (ip) values (v_ip);

  select id, nombre, telefono into v_pac
  from pacientes
  where organizacion_id = v_org and activo
    and upper(regexp_replace(coalesce(dni, ''), '[^0-9kK]', '', 'g')) = v_norm
  limit 1;
  if v_pac.id is null then return jsonb_build_object('encontrado', false); end if;

  v_dig := regexp_replace(coalesce(v_pac.telefono, ''), '\D', '', 'g');
  return jsonb_build_object(
    'encontrado', true,
    'nombre', split_part(trim(v_pac.nombre), ' ', 1),
    'telefono_final', case when length(v_dig) >= 4 then right(v_dig, 4) else null end
  );
end $$;
grant execute on function reservar_reconocer(text, text) to anon, authenticated;

-- Reserva por RUT: asocia el turno al paciente (por RUT; si no, por teléfono; si no, nuevo)
create or replace function crear_reserva_v2(
  p_slug text, p_nombre text, p_apellido text, p_dni text, p_telefono text,
  p_email text, p_servicio_id uuid, p_fecha_hora timestamptz, p_notas text default null)
returns json language plpgsql security definer set search_path = bienestar as $$
declare
  v_org uuid; v_pac uuid; v_dur int;
  v_rut text := rut_formato_cl(p_dni);
  v_norm text := upper(regexp_replace(coalesce(p_dni, ''), '[^0-9kK]', '', 'g'));
  v_tel text := nullif(trim(coalesce(p_telefono, '')), '');
  v_pac_tel text;
begin
  select id into v_org from organizaciones where slug = p_slug and activo = true;
  if v_org is null then raise exception 'Clínica no disponible'; end if;

  select duracion_min into v_dur from servicios
  where id = p_servicio_id and organizacion_id = v_org and activo = true;
  if not found then raise exception 'Servicio no válido para esta clínica'; end if;

  if coalesce(btrim(p_dni), '') <> '' and v_rut is null then raise exception 'El RUT no es válido'; end if;
  if p_fecha_hora is null or p_fecha_hora < now() - interval '1 hour' then raise exception 'Fecha u hora inválidas'; end if;

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
    if coalesce(btrim(p_nombre), '') = '' or coalesce(btrim(p_apellido), '') = '' then
      raise exception 'Faltan nombre y apellido';
    end if;
    insert into pacientes (organizacion_id, nombre, apellido, dni, telefono, email)
    values (v_org, left(trim(p_nombre), 80), left(trim(p_apellido), 80), v_rut, v_tel,
            nullif(left(trim(coalesce(p_email, '')), 120), ''))
    returning id into v_pac;
  end if;

  insert into turnos (organizacion_id, paciente_id, servicio_id, fecha_hora, duracion_min, estado, origen, notas)
  values (v_org, v_pac, p_servicio_id, p_fecha_hora, coalesce(v_dur, 60), 'pendiente', 'online',
          nullif(left(coalesce(p_notas, ''), 500), ''));

  return json_build_object('ok', true);
end $$;
grant execute on function crear_reserva_v2(text, text, text, text, text, text, uuid, timestamptz, text) to anon, authenticated;

notify pgrst, 'reload schema';
select 'v11 reserva reconoce paciente aplicada' as estado;
reset search_path;

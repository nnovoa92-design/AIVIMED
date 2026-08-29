-- ============================================================
-- SaaS — Endurecimiento de páginas públicas por clínica
-- Cierra el acceso directo anónimo a las tablas y lo reemplaza por
-- funciones SECURITY DEFINER que solo devuelven/aceptan datos de UNA clínica.
-- Ejecutar en el SQL Editor.
-- ============================================================
set search_path to bienestar;

-- 1) CERRAR políticas públicas "abiertas" (using/with check = true) en tablas
--    sensibles, sin depender de sus nombres. La app pública pasa a usar RPCs.
do $$
declare r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'bienestar'
      and tablename in ('servicios','categorias_servicios','config','pacientes','turnos','personal','personal_servicios')
      and ( btrim(coalesce(qual,'')) in ('true','(true)')
         or btrim(coalesce(with_check,'')) in ('true','(true)') )
  loop
    execute format('drop policy if exists %I on bienestar.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- 2) Datos necesarios para la página de reserva de UNA clínica (por slug).
--    Solo clínicas activas; solo servicios activos.
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
        'direccion', direccion, 'razon_social', coalesce(razon_social, v_nombre)
      ) from config where organizacion_id = v_org
    ),
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

-- 3) Crear una reserva pública (paciente + turno) en la clínica indicada.
--    Valida que la clínica esté activa y que el servicio le pertenezca.
create or replace function crear_reserva(
  p_slug text, p_nombre text, p_apellido text, p_dni text, p_telefono text,
  p_email text, p_servicio_id uuid, p_fecha_hora timestamptz, p_notas text default null)
returns json language plpgsql security definer set search_path = bienestar as $$
declare v_org uuid; v_pac uuid; v_dur int;
begin
  select id into v_org from organizaciones where slug = p_slug and activo = true;
  if v_org is null then raise exception 'Clínica no disponible'; end if;

  -- El servicio debe pertenecer a esa clínica y estar activo
  select duracion_min into v_dur from servicios
  where id = p_servicio_id and organizacion_id = v_org and activo = true;
  if not found then raise exception 'Servicio no válido para esta clínica'; end if;

  -- Reusar paciente por teléfono dentro de la misma clínica, o crearlo
  if coalesce(btrim(p_telefono),'') <> '' then
    select id into v_pac from pacientes
    where organizacion_id = v_org and telefono = p_telefono limit 1;
  end if;

  if v_pac is null then
    insert into pacientes (organizacion_id, nombre, apellido, dni, telefono, email)
    values (v_org, p_nombre, p_apellido, nullif(p_dni,''), nullif(p_telefono,''), nullif(p_email,''))
    returning id into v_pac;
  end if;

  insert into turnos (organizacion_id, paciente_id, servicio_id, fecha_hora, duracion_min, estado, origen, notas)
  values (v_org, v_pac, p_servicio_id, p_fecha_hora, coalesce(v_dur, 60), 'pendiente', 'online', nullif(p_notas,''));

  return json_build_object('ok', true);
end $$;
grant execute on function crear_reserva(text, text, text, text, text, text, uuid, timestamptz, text) to anon, authenticated;

-- 4) Marca de la clínica en la cotización pública (para no mostrar AIVIMED a otra clínica)
create or replace function obtener_cotizacion_publica(p_cot_id uuid)
returns json language sql security definer set search_path = bienestar as $$
  select json_build_object(
    'id', c.id, 'numero', c.numero, 'fecha', c.fecha, 'estado', c.estado,
    'con_iva', c.con_iva, 'notas', c.notas, 'observacion', c.observacion,
    'paciente', json_build_object('nombre', p.nombre, 'apellido', p.apellido),
    'clinica', json_build_object(
      'nombre', coalesce(o.nombre, cf.razon_social, 'AIVIMED'),
      'direccion', cf.direccion, 'correo', cf.correo),
    'items', coalesce((
      select json_agg(json_build_object(
        'descripcion', i.descripcion, 'cantidad', i.cantidad, 'precio_unitario', i.precio_unitario
      ) order by i.orden)
      from cotizacion_items i where i.cotizacion_id = c.id), '[]'::json)
  )
  from cotizaciones c
  join pacientes p on p.id = c.paciente_id
  left join organizaciones o on o.id = c.organizacion_id
  left join config cf on cf.organizacion_id = c.organizacion_id
  where c.id = p_cot_id;
$$;
grant execute on function obtener_cotizacion_publica(uuid) to anon, authenticated;

-- 5) Marca de la clínica en el consentimiento público
create or replace function obtener_consentimiento_publico(p_id uuid)
returns json language sql security definer set search_path = bienestar as $$
  select json_build_object(
    'id', c.id, 'fecha', c.fecha, 'firmado', c.firmado, 'firmado_en', c.firmado_en,
    'texto', c.texto_consentimiento, 'servicio', s.nombre,
    'paciente', json_build_object('nombre', p.nombre, 'apellido', p.apellido),
    'nombre_firmante', c.nombre_firmante, 'rut_firmante', c.rut_firmante,
    'clinica', json_build_object(
      'nombre', coalesce(o.nombre, cf.razon_social, 'AIVIMED'),
      'direccion', cf.direccion, 'correo', cf.correo)
  )
  from consentimientos c
  join pacientes p on p.id = c.paciente_id
  left join servicios s on s.id = c.servicio_id
  left join organizaciones o on o.id = c.organizacion_id
  left join config cf on cf.organizacion_id = c.organizacion_id
  where c.id = p_id;
$$;
grant execute on function obtener_consentimiento_publico(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
reset search_path;

-- ============================================================
-- v3: Respuesta pública de cotizaciones (aceptar/rechazar/observar)
-- vía funciones SECURITY DEFINER (no expone las tablas completas)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================
set search_path to bienestar;

-- Campo para guardar la observación del paciente
alter table cotizaciones add column if not exists observacion text;

-- Devuelve UNA cotización (por su UUID) con sus ítems, como JSON.
-- Solo quien tiene el enlace con el UUID puede verla (no se puede enumerar).
create or replace function bienestar.obtener_cotizacion_publica(p_cot_id uuid)
returns json
language sql
security definer
set search_path = bienestar
as $$
  select json_build_object(
    'id', c.id,
    'numero', c.numero,
    'fecha', c.fecha,
    'estado', c.estado,
    'con_iva', c.con_iva,
    'notas', c.notas,
    'observacion', c.observacion,
    'paciente', json_build_object('nombre', p.nombre, 'apellido', p.apellido),
    'items', coalesce((
      select json_agg(json_build_object(
        'descripcion', i.descripcion,
        'cantidad', i.cantidad,
        'precio_unitario', i.precio_unitario
      ) order by i.orden)
      from cotizacion_items i where i.cotizacion_id = c.id
    ), '[]'::json)
  )
  from cotizaciones c
  join pacientes p on p.id = c.paciente_id
  where c.id = p_cot_id;
$$;

-- Permite al paciente responder: aceptar, rechazar o dejar observación.
create or replace function bienestar.responder_cotizacion(p_cot_id uuid, p_accion text, p_obs text default null)
returns text
language plpgsql
security definer
set search_path = bienestar
as $$
begin
  if p_accion = 'aceptar' then
    update cotizaciones set estado = 'aprobada' where id = p_cot_id;
  elsif p_accion = 'rechazar' then
    update cotizaciones set estado = 'rechazada' where id = p_cot_id;
  end if;
  if p_obs is not null and btrim(p_obs) <> '' then
    update cotizaciones set observacion = p_obs where id = p_cot_id;
  end if;
  return 'ok';
end $$;

grant execute on function bienestar.obtener_cotizacion_publica(uuid) to anon, authenticated;
grant execute on function bienestar.responder_cotizacion(uuid, text, text) to anon, authenticated;

reset search_path;

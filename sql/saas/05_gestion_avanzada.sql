-- ============================================================
-- SaaS — Config por clínica + facturación + endurecimiento
-- Ejecutar en el SQL Editor.
-- ============================================================
set search_path to bienestar;

-- A) CONFIG POR CLÍNICA (una configuración por clínica)
alter table config drop constraint if exists config_single;
alter table config drop constraint if exists config_pkey;
alter table config add primary key (organizacion_id);

-- B) FACTURACIÓN / PLANES
alter table organizaciones add column if not exists fecha_vencimiento date;

-- C) ENDURECIMIENTO: quitar lecturas públicas amplias que exponían datos
drop policy if exists "public_read_turnos" on turnos;
drop policy if exists "public_read_personal" on personal;

create or replace function horarios_ocupados(p_org uuid, p_desde timestamptz, p_hasta timestamptz)
returns setof timestamptz
language sql security definer set search_path = bienestar as $$
  select fecha_hora from turnos
  where organizacion_id = p_org and estado <> 'cancelado'
    and fecha_hora >= p_desde and fecha_hora <= p_hasta;
$$;
grant execute on function horarios_ocupados(uuid, timestamptz, timestamptz) to anon, authenticated;

-- D) Estado de mi clínica (para bloquear clínicas suspendidas/inactivas)
create or replace function mi_estado() returns json
language sql stable security definer set search_path = bienestar as $$
  select json_build_object(
    'rol', p.rol,
    'organizacion_id', p.organizacion_id,
    'org_activa', coalesce(o.activo, true),
    'org_plan', coalesce(o.plan, 'activo')
  )
  from perfiles p left join organizaciones o on o.id = p.organizacion_id
  where p.id = auth.uid();
$$;
grant execute on function mi_estado() to authenticated;

-- E) Usuarios de una clínica (para la Torre): lista con datos de auth
create or replace function sa_usuarios_org(p_org uuid)
returns json language plpgsql security definer set search_path = bienestar as $$
begin
  if not is_superadmin() then raise exception 'No autorizado'; end if;
  return (select coalesce(json_agg(json_build_object(
    'id', p.id, 'nombre', p.nombre, 'email', p.email, 'rol', p.rol, 'activo', p.activo
  ) order by p.rol, p.nombre), '[]'::json)
  from perfiles p where p.organizacion_id = p_org);
end $$;
grant execute on function sa_usuarios_org(uuid) to authenticated;

-- F) Cambiar rol / activar-desactivar un usuario (súper-admin)
create or replace function sa_editar_usuario(p_uid uuid, p_rol text, p_activo boolean)
returns text language plpgsql security definer set search_path = bienestar as $$
begin
  if not is_superadmin() then raise exception 'No autorizado'; end if;
  if p_rol not in ('admin','profesional','recepcion') then raise exception 'Rol invalido'; end if;
  update perfiles set rol = p_rol, activo = p_activo where id = p_uid;
  return 'OK';
end $$;
grant execute on function sa_editar_usuario(uuid, text, boolean) to authenticated;

reset search_path;

-- ============================================================
-- SaaS — Función para que el súper-admin asigne usuarios a clínicas
-- (crear el login se hace en Supabase Auth; esto lo vincula a una clínica)
-- ============================================================
set search_path to bienestar;

create or replace function sa_asignar_usuario(p_email text, p_org_id uuid, p_rol text, p_nombre text)
returns text language plpgsql security definer set search_path = bienestar as $$
declare v_uid uuid;
begin
  if not is_superadmin() then raise exception 'No autorizado'; end if;
  if p_rol not in ('admin','profesional','recepcion') then raise exception 'Rol invalido'; end if;
  select id into v_uid from auth.users where lower(email) = lower(p_email);
  if v_uid is null then return 'NO_USER'; end if;
  insert into perfiles (id, organizacion_id, rol, nombre, email)
  values (v_uid, p_org_id, p_rol, coalesce(nullif(p_nombre,''), p_email), p_email)
  on conflict (id) do update
    set organizacion_id = p_org_id, rol = p_rol,
        nombre = coalesce(nullif(p_nombre,''), perfiles.nombre);
  return 'OK';
end $$;

grant execute on function sa_asignar_usuario(text, uuid, text, text) to authenticated;

reset search_path;

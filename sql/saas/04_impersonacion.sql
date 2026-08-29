-- ============================================================
-- SaaS — Impersonación de clínica por el súper-admin + defaults de org
-- Ejecutar en el SQL Editor.
-- ============================================================
set search_path to bienestar;

-- 1) current_org(): súper-admin usa la clínica "en la que entró" (header x-acting-org)
create or replace function current_org() returns uuid
language plpgsql stable security definer set search_path = bienestar as $$
declare v_super boolean; v_hdr text;
begin
  select (rol = 'superadmin') into v_super from perfiles where id = auth.uid();
  if coalesce(v_super, false) then
    begin
      v_hdr := current_setting('request.headers', true)::json ->> 'x-acting-org';
    exception when others then v_hdr := null; end;
    if v_hdr is not null and v_hdr <> '' then return v_hdr::uuid; end if;
    return null;
  end if;
  return (select organizacion_id from perfiles where id = auth.uid());
end $$;

-- 2) RLS de datos: aislar por current_org() + default automático al insertar
do $$ declare t text; begin
  foreach t in array array[
    'pacientes','categorias_servicios','servicios','personal','personal_servicios',
    'tratamientos','turnos','sesiones','insumos','sesion_insumos','movimientos_stock',
    'cotizaciones','cotizacion_items','pagos','consentimientos','config'
  ] loop
    execute format('drop policy if exists "org_isolation" on %I', t);
    execute format('create policy "org_isolation" on %I for all using (organizacion_id = current_org()) with check (organizacion_id = current_org())', t);
    execute format('alter table %I alter column organizacion_id set default current_org()', t);
  end loop;
end $$;

-- 3) Métricas globales para la Torre
create or replace function sa_metricas() returns json
language plpgsql security definer set search_path = bienestar as $$
begin
  if not is_superadmin() then raise exception 'No autorizado'; end if;
  return (select json_build_object(
    'orgs', coalesce((select json_agg(json_build_object(
        'id', o.id,
        'pacientes', (select count(*) from pacientes p where p.organizacion_id = o.id),
        'usuarios', (select count(*) from perfiles pf where pf.organizacion_id = o.id),
        'turnos', (select count(*) from turnos tt where tt.organizacion_id = o.id),
        'cotizaciones', (select count(*) from cotizaciones c where c.organizacion_id = o.id)
      ) order by o.nombre) from organizaciones o), '[]'::json),
    'total_pacientes', (select count(*) from pacientes),
    'total_usuarios', (select count(*) from perfiles where organizacion_id is not null)
  ));
end $$;
grant execute on function sa_metricas() to authenticated;

-- 4) RPC pública: clínica por slug (para páginas públicas por clínica)
create or replace function org_por_slug(p_slug text) returns json
language sql security definer set search_path = bienestar as $$
  select json_build_object('id', id, 'nombre', nombre, 'slug', slug, 'activo', activo)
  from organizaciones where slug = p_slug and activo = true;
$$;
grant execute on function org_por_slug(text) to anon, authenticated;

reset search_path;

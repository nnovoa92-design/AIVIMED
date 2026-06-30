-- ============================================================
-- v5: Consentimientos — plantilla por procedimiento, firma remota,
-- registro auditable. Ejecutar en el SQL Editor de Supabase.
-- ============================================================
set search_path to bienestar;

-- Plantilla de consentimiento por servicio (texto editable; opcional)
alter table servicios add column if not exists consentimiento_template text;

-- Sello de firma (cuándo se firmó)
alter table consentimientos add column if not exists firmado_en timestamptz;

reset search_path;

-- Devuelve un consentimiento por UUID (para firma remota), como JSON
create or replace function bienestar.obtener_consentimiento_publico(p_id uuid)
returns json
language sql
security definer
set search_path = bienestar
as $$
  select json_build_object(
    'id', c.id,
    'fecha', c.fecha,
    'firmado', c.firmado,
    'firmado_en', c.firmado_en,
    'texto', c.texto_consentimiento,
    'servicio', s.nombre,
    'paciente', json_build_object('nombre', p.nombre, 'apellido', p.apellido),
    'nombre_firmante', c.nombre_firmante,
    'rut_firmante', c.rut_firmante
  )
  from consentimientos c
  join pacientes p on p.id = c.paciente_id
  left join servicios s on s.id = c.servicio_id
  where c.id = p_id;
$$;

-- El paciente firma desde su celular (solo si está pendiente)
create or replace function bienestar.firmar_consentimiento(p_id uuid, p_firma text, p_nombre text, p_rut text)
returns text
language plpgsql
security definer
set search_path = bienestar
as $$
begin
  update consentimientos
    set firma_data = p_firma,
        firmado = true,
        firmado_en = now(),
        nombre_firmante = coalesce(nullif(p_nombre, ''), nombre_firmante),
        rut_firmante = coalesce(nullif(p_rut, ''), rut_firmante)
  where id = p_id and firmado = false;
  return 'ok';
end $$;

grant execute on function bienestar.obtener_consentimiento_publico(uuid) to anon, authenticated;
grant execute on function bienestar.firmar_consentimiento(uuid, text, text, text) to anon, authenticated;

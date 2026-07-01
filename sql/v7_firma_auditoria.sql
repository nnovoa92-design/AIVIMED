-- ============================================================
-- v7: Auditoría de firma de consentimientos (dispositivo + IP)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================
set search_path to bienestar;

alter table consentimientos add column if not exists firma_user_agent text;
alter table consentimientos add column if not exists firma_ip text;

reset search_path;

-- Firmar capturando dispositivo (user agent) e IP (desde los headers de la request)
create or replace function bienestar.firmar_consentimiento(
  p_id uuid, p_firma text, p_nombre text, p_rut text, p_user_agent text default null)
returns text
language plpgsql
security definer
set search_path = bienestar
as $$
declare
  v_ip text;
begin
  begin
    v_ip := split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1);
  exception when others then
    v_ip := null;
  end;

  update consentimientos
    set firma_data = p_firma,
        firmado = true,
        firmado_en = now(),
        nombre_firmante = coalesce(nullif(p_nombre, ''), nombre_firmante),
        rut_firmante = coalesce(nullif(p_rut, ''), rut_firmante),
        firma_user_agent = nullif(p_user_agent, ''),
        firma_ip = nullif(btrim(v_ip), '')
  where id = p_id and firmado = false;
  return 'ok';
end $$;

grant execute on function bienestar.firmar_consentimiento(uuid, text, text, text, text) to anon, authenticated;

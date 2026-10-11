-- ============================================================
-- v9: Unifica el formato de RUT y teléfonos ya guardados.
-- Solo cambia el FORMATO, nunca los números.
-- No toca lo ambiguo (teléfonos que no tengan 9 dígitos, números de otro país,
-- documentos con letras) ni RUT que quedarían duplicados.
-- Deja respaldo de cada valor cambiado en bienestar.respaldo_formatos.
-- Seguro de correr más de una vez.
-- ============================================================
set search_path to bienestar;

-- 0) El RUT debe ser único POR CLÍNICA (no global): dos clínicas pueden atender
--    a la misma persona. Se elimina la restricción única global sobre "dni"
--    (sea cual sea su nombre) y se crea una por (organizacion_id, dni).
do $$
declare r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'bienestar.pacientes'::regclass
      and c.contype = 'u'
      and (select array_agg(a.attname::text order by a.attname)
           from pg_attribute a
           where a.attrelid = c.conrelid and a.attnum = any(c.conkey)) = array['dni']
  loop
    execute format('alter table bienestar.pacientes drop constraint %I', r.conname);
  end loop;
end $$;

create unique index if not exists uq_pacientes_org_dni on pacientes (organizacion_id, dni);

-- 1) Funciones de formato (temporales)
create or replace function _fmt_rut(p text) returns text language plpgsql immutable as $$
declare v text; cuerpo text;
begin
  if p is null or btrim(p) = '' then return p; end if;
  if p ~ '[A-JL-Za-jl-z]' then return p; end if;
  v := upper(regexp_replace(p, '[^0-9kK]', '', 'g'));
  if v !~ '^[0-9]{6,8}[0-9K]$' then return p; end if;
  cuerpo := (left(v, length(v) - 1))::bigint::text;
  return replace(to_char(cuerpo::bigint, 'FM999,999,999'), ',', '.') || '-' || right(v, 1);
end $$;

create or replace function _fmt_tel(p text) returns text language plpgsql immutable as $$
declare d text; n text;
begin
  if p is null or btrim(p) = '' then return p; end if;
  d := regexp_replace(p, '\D', '', 'g');
  if btrim(p) like '+%' and d not like '56%' then return p; end if;
  if d like '56%' and length(d) = 11 then n := substr(d, 3); else n := regexp_replace(d, '^0+', ''); end if;
  if length(n) <> 9 then return p; end if;
  if n like '9%' then return '+56 9 ' || substr(n, 2, 4) || ' ' || substr(n, 6, 4);
  elsif n like '2%' then return '+56 2 ' || substr(n, 2, 4) || ' ' || substr(n, 6, 4);
  else return '+56 ' || substr(n, 1, 2) || ' ' || substr(n, 3, 3) || ' ' || substr(n, 6, 4);
  end if;
end $$;

-- 2) Respaldo (solo visible desde el panel de Supabase)
create table if not exists respaldo_formatos (
  tabla text not null, id text, campo text not null, valor_anterior text,
  cambiado_en timestamptz not null default now()
);
alter table respaldo_formatos enable row level security;      -- sin políticas
revoke all on respaldo_formatos from anon, authenticated;

-- 3) RUT de pacientes (columna dni): se evita crear duplicados dentro de la clínica
with cand as (
  select id, organizacion_id, dni as antes, _fmt_rut(dni) as despues,
         row_number() over (partition by organizacion_id, _fmt_rut(dni) order by creado_en, id) as rn
  from pacientes where dni is not null
),
cambios as (
  select c.id, c.antes, c.despues from cand c
  where c.antes is distinct from c.despues and c.rn = 1
    and not exists (select 1 from pacientes x
                    where x.organizacion_id = c.organizacion_id and x.dni = c.despues and x.id <> c.id)
),
resp as (
  insert into respaldo_formatos (tabla, id, campo, valor_anterior)
  select 'pacientes', id::text, 'dni', antes from cambios returning 1
)
update pacientes p set dni = cambios.despues from cambios where p.id = cambios.id;

-- 4) Teléfonos y demás RUT (si alguna tabla/columna no existe, se omite)
do $$
declare r record;
begin
  for r in select * from (values
      ('config', 'rut', '_fmt_rut'),
      ('pacientes', 'telefono', '_fmt_tel'),
      ('pacientes', 'contacto_emergencia_telefono', '_fmt_tel'),
      ('personal', 'telefono', '_fmt_tel'),
      ('config', 'telefono', '_fmt_tel')
    ) as t(tabla, columna, funcion)
  loop
    if to_regclass('bienestar.' || r.tabla) is null then continue; end if;
    if not exists (select 1 from information_schema.columns
                   where table_schema = 'bienestar' and table_name = r.tabla and column_name = r.columna) then continue; end if;
    execute format(
      'insert into respaldo_formatos (tabla, id, campo, valor_anterior)
         select %L, (to_jsonb(t) ->> ''id''), %L, t.%I from %I t
         where t.%I is not null and %I(t.%I) is distinct from t.%I',
      r.tabla, r.columna, r.columna, r.tabla, r.columna, r.funcion, r.columna, r.columna);
    execute format(
      'update %I t set %I = %I(t.%I) where t.%I is not null and %I(t.%I) is distinct from t.%I',
      r.tabla, r.columna, r.funcion, r.columna, r.columna, r.funcion, r.columna, r.columna);
  end loop;
end $$;

drop function if exists _fmt_rut(text);
drop function if exists _fmt_tel(text);

select 'v9 formatos unificados' as estado,
       (select count(*) from respaldo_formatos where campo = 'dni') as ruts_cambiados,
       (select count(*) from respaldo_formatos where campo like '%telefono%') as telefonos_cambiados,
       (select count(*) from pacientes where dni is not null and dni !~ '^[0-9]{1,2}\.[0-9]{3}\.[0-9]{3}-[0-9K]$') as ruts_por_revisar;

reset search_path;

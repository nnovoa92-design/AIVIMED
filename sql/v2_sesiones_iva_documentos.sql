-- ============================================================
-- Migración v2: 2ª profesional, IVA opcional y documentos de pago
-- Ejecutar en el SQL Editor de Supabase (schema bienestar)
-- ============================================================
set search_path to bienestar;

-- 1) Sesiones: segunda profesional de apoyo
alter table sesiones add column if not exists personal_apoyo_id uuid references personal(id) on delete set null;

-- 2) Cotizaciones: IVA opcional
alter table cotizaciones add column if not exists con_iva boolean not null default false;

-- 3) Pagos: IVA, tipo de documento y vínculo a cotización (para contabilidad sin duplicar)
alter table pagos add column if not exists con_iva boolean not null default false;
alter table pagos add column if not exists tipo_documento text not null default 'ninguno'
  check (tipo_documento in ('ninguno', 'boleta', 'factura'));
alter table pagos add column if not exists cotizacion_id uuid references cotizaciones(id) on delete set null;

create index if not exists idx_pagos_cotizacion on pagos (cotizacion_id);

reset search_path;

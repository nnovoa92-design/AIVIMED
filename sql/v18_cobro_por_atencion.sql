-- ============================================================
-- v18: Cobro por atención — total a pagar, abonos, método de pago y saldo.
--
--  · turnos.total_pagar        → lo que debe pagar el paciente por esa atención
--  · pagos.visita_id           → los pagos (abonos) también pueden pertenecer a una
--                                 visita domiciliaria (los de un turno ya usaban pagos.turno_id)
--  · detalles_atencion.pago_info → foto del estado de pago al preparar un Detalle de atención
--
-- Los abonos NO son una tabla nueva: son filas de "pagos" (así el ingreso se cuenta una sola
-- vez en la Torre de Control, el inicio y el historial).
-- Saldo de una atención = total a pagar − suma de sus pagos.
--
-- Todos los nombres van con "bienestar." Ejecutar el script COMPLETO (Ctrl+A antes de pegar).
-- Seguro de correr más de una vez.
-- ============================================================

alter table bienestar.turnos add column if not exists total_pagar numeric(12,0);
alter table bienestar.pagos add column if not exists visita_id uuid references bienestar.visitas_cuidado(id) on delete set null;
alter table bienestar.detalles_atencion add column if not exists pago_info jsonb;

create index if not exists idx_pagos_turno on bienestar.pagos (turno_id);
create index if not exists idx_pagos_visita on bienestar.pagos (visita_id);

notify pgrst, 'reload schema';

-- Verificación: debe mostrar columnas = 3
select 'v18 cobro por atencion aplicado' as estado,
       (select count(*) from information_schema.columns
         where table_schema = 'bienestar'
           and ((table_name = 'turnos' and column_name = 'total_pagar')
             or (table_name = 'pagos' and column_name = 'visita_id')
             or (table_name = 'detalles_atencion' and column_name = 'pago_info'))) as columnas;

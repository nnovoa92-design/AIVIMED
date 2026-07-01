-- ============================================================
-- v8: Origen del turno (interno vs reserva online)
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================
set search_path to bienestar;

alter table turnos add column if not exists origen text not null default 'interno'
  check (origen in ('interno', 'online'));

reset search_path;

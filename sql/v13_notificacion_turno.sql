-- ============================================================
-- v13: La notificación de "Nueva reserva online" recuerda su turno,
-- para poder confirmar la cita y enviar el mensaje desde la campanita.
-- Requiere v10. Seguro de correr más de una vez.
-- ============================================================
set search_path to bienestar;

-- Turno al que pertenece la novedad (si el turno se elimina, la novedad también)
alter table notificaciones
  add column if not exists turno_id uuid references turnos(id) on delete cascade;
create index if not exists idx_notificaciones_turno on notificaciones (turno_id);

-- El trigger de reserva online ahora guarda el turno
create or replace function notif_turno_online() returns trigger
language plpgsql security definer set search_path = bienestar as $$
declare v_pac text; v_srv text;
begin
  begin
    select trim(nombre || ' ' || coalesce(apellido, '')) into v_pac from pacientes where id = new.paciente_id;
    select nombre into v_srv from servicios where id = new.servicio_id;
    insert into notificaciones (organizacion_id, tipo, titulo, detalle, url, turno_id)
    values (new.organizacion_id, 'reserva_online', 'Nueva reserva online',
      coalesce(nullif(v_pac, ''), 'Paciente') || ' · ' || coalesce(v_srv, 'Servicio')
        || ' · ' || to_char(new.fecha_hora at time zone 'America/Santiago', 'DD-MM HH24:MI'),
      'agenda.html', new.id);
  exception when others then null;   -- un fallo al avisar nunca debe impedir la reserva
  end;
  return new;
end $$;

notify pgrst, 'reload schema';
select 'v13 notificacion con turno aplicado' as estado;
reset search_path;

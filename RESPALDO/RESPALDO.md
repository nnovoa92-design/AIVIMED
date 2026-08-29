# Estrategia de respaldo — AIVIMED

## 1. Código (automático ✅)
Cada cambio se guarda con `git commit` + `git push` a **GitHub**:
https://github.com/nnovoa92-design/AIVIMED

- Es un respaldo **versionado y en la nube**: puedes ver y recuperar cualquier versión anterior.
- No hay que hacer nada manual: al desplegar, el código queda respaldado.
- Para descargar una copia completa en cualquier momento: en GitHub → botón verde **Code → Download ZIP**.

## 2. Documentación / contexto del proyecto (se mantiene al día)
`RESPALDO/PROYECTO.md` es el "libro del proyecto": arquitectura, módulos, decisiones,
datos de empresa y pendientes. Se actualiza con cada cambio y viaja en el repo.
`RESPALDO/BITACORA.md` es el registro cronológico de qué se hizo.

## 3. Datos de la base (Supabase) — respaldo recomendado
El código NO incluye los datos (pacientes, turnos, sesiones, pagos…). Esos viven en Supabase.
Opciones para respaldarlos:

### a) Backups de Supabase (lo más simple)
- En el Dashboard de Supabase → **Database → Backups**. El plan Free tiene backups
  diarios limitados; el plan Pro conserva más días y permite restaurar con un clic.

### b) Exportar a mano cuando quieras (gratis)
En el **SQL Editor** de Supabase puedes exportar cualquier tabla a CSV con el botón de
descarga de resultados, por ejemplo:
```sql
select * from bienestar.pacientes;
select * from bienestar.turnos;
select * from bienestar.sesiones;
select * from bienestar.cotizaciones;
select * from bienestar.pagos;
```
Ejecutas cada una y descargas el CSV.

### c) Botón de exportación en la app (opcional, a pedido)
Se puede agregar en Configuración un botón "Descargar respaldo" que baje un archivo
JSON con todas las tablas. Si lo quieres, pídemelo y lo construyo.

## 4. Recomendación de frecuencia
- Código: ya es automático en cada cambio.
- Datos: exportar una vez por semana (o activar backups Pro de Supabase si el volumen crece).

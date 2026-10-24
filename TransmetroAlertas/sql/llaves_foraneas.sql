USE transmetro_db;

-- =====================================================================
-- PASO 1: DIAGNOSTICO. Todas las filas deben dar 0.
-- Si alguna da mayor a 0, corrige esos datos ANTES de ejecutar el paso 2
-- (si no, MySQL rechazara la llave foranea correspondiente).
-- =====================================================================
SELECT 'distancias_tramos con ruta inexistente' AS problema, COUNT(*) AS filas
  FROM distancias_tramos d LEFT JOIN rutas_operativas r ON d.id_ruta = r.id_ruta WHERE r.id_ruta IS NULL
UNION ALL
SELECT 'flota_vehiculos con parqueo inexistente', COUNT(*)
  FROM flota_vehiculos f LEFT JOIN parqueos p ON f.id_parqueo = p.id_parqueo WHERE p.id_parqueo IS NULL
UNION ALL
SELECT 'rutas con vehiculo principal inexistente', COUNT(*)
  FROM rutas_operativas r LEFT JOIN flota_vehiculos f ON r.id_vehiculo_main = f.id_vehiculo WHERE f.id_vehiculo IS NULL
UNION ALL
SELECT 'rutas con vehiculo de respaldo inexistente', COUNT(*)
  FROM rutas_operativas r LEFT JOIN flota_vehiculos f ON r.id_vehiculo_backup = f.id_vehiculo WHERE f.id_vehiculo IS NULL
UNION ALL
SELECT 'rutas con vehiculo extra inexistente', COUNT(*)
  FROM rutas_operativas r LEFT JOIN flota_vehiculos f ON r.id_vehiculo_extra = f.id_vehiculo
  WHERE r.id_vehiculo_extra IS NOT NULL AND f.id_vehiculo IS NULL;

-- =====================================================================
-- PASO 2: LLAVES FORANEAS (ejecutar solo si el paso 1 dio todo en 0)
-- =====================================================================

-- RF02: un tramo siempre pertenece a una ruta. Si se borra la ruta, se borran sus tramos.
ALTER TABLE distancias_tramos
  ADD CONSTRAINT fk_distancias_ruta
  FOREIGN KEY (id_ruta) REFERENCES rutas_operativas (id_ruta)
  ON DELETE CASCADE;

-- RN04: todo vehiculo debe estar en un parqueo existente (no se puede borrar un parqueo con buses).
ALTER TABLE flota_vehiculos
  ADD CONSTRAINT fk_flota_parqueo
  FOREIGN KEY (id_parqueo) REFERENCES parqueos (id_parqueo);

-- NOTA: NO se crea llave de asientos hacia buses. operacion.jsp usa asientos.id_bus
-- como id_vehiculo de flota_vehiculos (la tabla buses es del esquema antiguo).
-- Si ya habias ejecutado una version anterior de este script que la creaba, revierte con:
--   ALTER TABLE asientos DROP FOREIGN KEY fk_asientos_bus;

-- Los vehiculos de una ruta deben existir en la flota (no se puede borrar un vehiculo en uso).
-- El vehiculo extra y el piloto titular son opcionales: si se borran, quedan en NULL.
-- Nota: los JSP agregan automaticamente la columna id_piloto si aun no existe.
ALTER TABLE rutas_operativas
  ADD COLUMN IF NOT EXISTS id_piloto INT DEFAULT NULL;

ALTER TABLE rutas_operativas
  ADD CONSTRAINT fk_ruta_vehiculo_main
  FOREIGN KEY (id_vehiculo_main) REFERENCES flota_vehiculos (id_vehiculo),
  ADD CONSTRAINT fk_ruta_vehiculo_backup
  FOREIGN KEY (id_vehiculo_backup) REFERENCES flota_vehiculos (id_vehiculo),
  ADD CONSTRAINT fk_ruta_vehiculo_extra
  FOREIGN KEY (id_vehiculo_extra) REFERENCES flota_vehiculos (id_vehiculo)
  ON DELETE SET NULL,
  ADD CONSTRAINT fk_ruta_piloto
  FOREIGN KEY (id_piloto) REFERENCES pilotos_catalogo (id)
  ON DELETE SET NULL;

-- Verificacion: lista las llaves foraneas creadas
SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME
  FROM information_schema.KEY_COLUMN_USAGE
 WHERE TABLE_SCHEMA = 'transmetro_db' AND REFERENCED_TABLE_NAME IS NOT NULL
 ORDER BY TABLE_NAME;

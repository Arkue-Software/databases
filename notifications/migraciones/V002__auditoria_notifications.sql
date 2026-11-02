-- =============================================================================
-- Servicio: notifications
-- Migración: V002__auditoria_notifications.sql
-- Descripción: Infraestructura de auditoría DML para el esquema notifications.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tabla: notifications.auditoria_notificaciones
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications.auditoria_notificaciones (
    id BIGSERIAL PRIMARY KEY,
    tabla_afectada VARCHAR(100) NOT NULL,
    operacion VARCHAR(10) NOT NULL,
    registro_id VARCHAR(255) NOT NULL,
    datos_anteriores JSONB NULL,
    datos_nuevos JSONB NULL,
    usuario_db VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,
    fecha_auditoria TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_auditoria_operacion CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX IF NOT EXISTS idx_auditoria_tabla_registro 
    ON notifications.auditoria_notificaciones(tabla_afectada, registro_id);

CREATE INDEX IF NOT EXISTS idx_auditoria_fecha 
    ON notifications.auditoria_notificaciones(fecha_auditoria);

-- -----------------------------------------------------------------------------
-- Función Genérica de Auditoría
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION notifications.fn_auditar_cambios()
RETURNS TRIGGER AS $$
DECLARE
    v_registro_id VARCHAR(255);
    v_datos_anteriores JSONB := NULL;
    v_datos_nuevos JSONB := NULL;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_registro_id := OLD.id::VARCHAR;
        v_datos_anteriores := to_jsonb(OLD);
        INSERT INTO notifications.auditoria_notificaciones (
            tabla_afectada, operacion, registro_id, datos_anteriores, datos_nuevos
        ) VALUES (
            TG_TABLE_NAME, TG_OP, v_registro_id, v_datos_anteriores, NULL
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_registro_id := NEW.id::VARCHAR;
        v_datos_anteriores := to_jsonb(OLD);
        v_datos_nuevos := to_jsonb(NEW);
        INSERT INTO notifications.auditoria_notificaciones (
            tabla_afectada, operacion, registro_id, datos_anteriores, datos_nuevos
        ) VALUES (
            TG_TABLE_NAME, TG_OP, v_registro_id, v_datos_anteriores, v_datos_nuevos
        );
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        v_registro_id := NEW.id::VARCHAR;
        v_datos_nuevos := to_jsonb(NEW);
        INSERT INTO notifications.auditoria_notificaciones (
            tabla_afectada, operacion, registro_id, datos_anteriores, datos_nuevos
        ) VALUES (
            TG_TABLE_NAME, TG_OP, v_registro_id, NULL, v_datos_nuevos
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- Triggers de auditoría en tablas críticas
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_auditar_plantillas ON notifications.plantillas;
CREATE TRIGGER trg_auditar_plantillas
    AFTER INSERT OR UPDATE OR DELETE ON notifications.plantillas
    FOR EACH ROW
    EXECUTE FUNCTION notifications.fn_auditar_cambios();

DROP TRIGGER IF EXISTS trg_auditar_avisos ON notifications.avisos;
CREATE TRIGGER trg_auditar_avisos
    AFTER INSERT OR UPDATE OR DELETE ON notifications.avisos
    FOR EACH ROW
    EXECUTE FUNCTION notifications.fn_auditar_cambios();

-- Permisos
GRANT SELECT, INSERT ON notifications.auditoria_notificaciones TO notifications_app;
GRANT USAGE, SELECT ON SEQUENCE notifications.auditoria_notificaciones_id_seq TO notifications_app;
GRANT SELECT ON notifications.auditoria_notificaciones TO notifications_read_only;
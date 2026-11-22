-- =============================================================================
-- Servicio: notifications
-- Migración: V003__bandeja_idempotencia_notifications.sql
-- Descripción: Registro de eventos procesados para consumo idempotente de mensajes.
-- =============================================================================

CREATE TABLE IF NOT EXISTS notifications.bandeja_idempotencia (
    clave_idempotencia VARCHAR(255) PRIMARY KEY,
    evento_origen VARCHAR(100) NOT NULL,
    aviso_id UUID NULL,
    resultado JSONB NOT NULL DEFAULT '{}'::jsonb,
    procesado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bandeja_idempotencia_aviso FOREIGN KEY (aviso_id) 
        REFERENCES notifications.avisos(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_bandeja_idempotencia_procesado 
    ON notifications.bandeja_idempotencia(procesado_en);

GRANT SELECT, INSERT, UPDATE ON notifications.bandeja_idempotencia TO notifications_app;
GRANT SELECT ON notifications.bandeja_idempotencia TO notifications_read_only;
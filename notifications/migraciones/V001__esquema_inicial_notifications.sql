-- =============================================================================
-- Servicio: notifications
-- Migración: V001__esquema_inicial_notifications.sql
-- Descripción: Tablas principales para plantillas, avisos e historial de fallos.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- Tabla: notifications.plantillas
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications.plantillas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(100) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    canal VARCHAR(50) NOT NULL,
    asunto_patron VARCHAR(500) NULL,
    cuerpo_patron TEXT NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_plantillas_codigo UNIQUE (codigo),
    CONSTRAINT chk_plantillas_canal CHECK (canal IN ('CORREO', 'SMS', 'PUSH', 'WHATSAPP'))
);

-- -----------------------------------------------------------------------------
-- Tabla: notifications.avisos
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications.avisos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plantilla_id UUID NULL,
    canal VARCHAR(50) NOT NULL,
    destinatario VARCHAR(255) NOT NULL,
    asunto VARCHAR(500) NULL,
    contenido TEXT NULL,
    parametros JSONB NOT NULL DEFAULT '{}'::jsonb,
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE',
    intentos INTEGER NOT NULL DEFAULT 0,
    max_intentos INTEGER NOT NULL DEFAULT 3,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_programada TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega TIMESTAMPTZ NULL,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_avisos_plantilla FOREIGN KEY (plantilla_id) 
        REFERENCES notifications.plantillas(id) ON DELETE SET NULL,
    CONSTRAINT chk_avisos_canal CHECK (canal IN ('CORREO', 'SMS', 'PUSH', 'WHATSAPP')),
    CONSTRAINT chk_avisos_estado CHECK (estado IN ('PENDIENTE', 'EN_PROCESO', 'ENTREGADO', 'FALLIDO', 'CANCELADO')),
    CONSTRAINT chk_avisos_intentos CHECK (intentos >= 0 AND max_intentos > 0)
);

-- -----------------------------------------------------------------------------
-- Tabla: notifications.fallos_entrega
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications.fallos_entrega (
    id BIGSERIAL PRIMARY KEY,
    aviso_id UUID NOT NULL,
    numero_intento INTEGER NOT NULL,
    tipo_fallo VARCHAR(100) NOT NULL,
    detalle_fallo TEXT NOT NULL,
    reintentable BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_fallo TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fallos_entrega_aviso FOREIGN KEY (aviso_id) 
        REFERENCES notifications.avisos(id) ON DELETE CASCADE,
    CONSTRAINT chk_fallos_entrega_intento CHECK (numero_intento > 0)
);

-- -----------------------------------------------------------------------------
-- Índices de rendimiento
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_plantillas_codigo 
    ON notifications.plantillas(codigo);

CREATE INDEX IF NOT EXISTS idx_avisos_estado_programada 
    ON notifications.avisos(estado, fecha_programada) 
    WHERE estado IN ('PENDIENTE', 'EN_PROCESO');

CREATE INDEX IF NOT EXISTS idx_avisos_destinatario 
    ON notifications.avisos(destinatario);

CREATE INDEX IF NOT EXISTS idx_avisos_plantilla_id 
    ON notifications.avisos(plantilla_id);

CREATE INDEX IF NOT EXISTS idx_fallos_entrega_aviso_id 
    ON notifications.fallos_entrega(aviso_id);

-- -----------------------------------------------------------------------------
-- Trigger de actualización automática de timestamps
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION notifications.fn_actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_plantillas_actualizar_fecha ON notifications.plantillas;
CREATE TRIGGER trg_plantillas_actualizar_fecha
    BEFORE UPDATE ON notifications.plantillas
    FOR EACH ROW
    EXECUTE FUNCTION notifications.fn_actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS trg_avisos_actualizar_fecha ON notifications.avisos;
CREATE TRIGGER trg_avisos_actualizar_fecha
    BEFORE UPDATE ON notifications.avisos
    FOR EACH ROW
    EXECUTE FUNCTION notifications.fn_actualizar_fecha_modificacion();

-- Asignación explícita de permisos sobre objetos creados
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA notifications TO notifications_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA notifications TO notifications_app;
GRANT SELECT ON ALL TABLES IN SCHEMA notifications TO notifications_read_only;
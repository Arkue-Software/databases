-- RedVital · db_campana · V003 — Eventos con Donación por Kafka (ADR-018)
-- Campañas publica campaign.published por su bandeja de salida y consume
-- donation.completed para contar las donaciones de cada campaña (RF-25).
-- Toda comunicación entre Campañas y Donación pasa por Kafka.

-- RF-25 / D-09: un conteo, sin ningún vínculo con donantes ni reservas.
ALTER TABLE campania
    ADD COLUMN donaciones_registradas INTEGER NOT NULL DEFAULT 0
        CONSTRAINT ck_campania_donaciones CHECK (donaciones_registradas >= 0);

-- Bandeja de salida: estructura común de toda base que publica (DD 5.3.6).
CREATE TABLE evento_salida (
    id                    UUID PRIMARY KEY,
    secuencia             BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    tipo                  VARCHAR(80)  NOT NULL CHECK (tipo IN ('campaign.published')),
    version_esquema       INTEGER      NOT NULL CHECK (version_esquema > 0),
    tema                  VARCHAR(120) NOT NULL,
    clave                 VARCHAR(64)  NOT NULL,
    carga                 JSONB        NOT NULL,
    clave_natural         VARCHAR(160) UNIQUE,
    correlacion_id        VARCHAR(36)  NOT NULL,
    estado                VARCHAR(20)  NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'publicado')),
    intentos_publicacion  INTEGER      NOT NULL DEFAULT 0,
    creado_en             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    publicado_en          TIMESTAMPTZ,
    expira_en             TIMESTAMPTZ,
    CONSTRAINT ck_evento_salida_publicado CHECK ((estado = 'publicado') = (publicado_en IS NOT NULL)),
    CONSTRAINT ck_evento_salida_expira CHECK (estado = 'publicado' OR expira_en IS NULL)
);
CREATE INDEX ix_evento_salida_pendiente ON evento_salida(secuencia) WHERE estado = 'pendiente';

-- Eventos aplicados por el consumidor, grupo campanias.
CREATE TABLE evento_procesado (
    grupo_consumidor  VARCHAR(60) NOT NULL,
    evento_id         UUID        NOT NULL,
    tipo              VARCHAR(80) NOT NULL,
    procesado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en         TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (grupo_consumidor, evento_id)
);

GRANT SELECT, INSERT, DELETE ON evento_salida TO campana_servicio;
GRANT UPDATE (estado, intentos_publicacion, publicado_en, expira_en) ON evento_salida TO campana_servicio;
GRANT SELECT, INSERT, DELETE ON evento_procesado TO campana_servicio;

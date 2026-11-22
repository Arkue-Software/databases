-- RedVital · db_identidad · V005 — Bandeja de salida (ADR-018).
--
-- Los servicios solo se comunican por Kafka. Identidad publica cada registro
-- de su serie de auditoría (EV-10, audit.recorded) para que el Servicio
-- Institucional componga la bitácora sin consultarle nada. El evento se
-- escribe en la misma transacción que el registro, con la estructura común
-- de toda base que publica (DD 5.3.6).

CREATE TABLE evento_salida (
    id                    UUID PRIMARY KEY,
    secuencia             BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    tipo                  VARCHAR(80)  NOT NULL CHECK (tipo IN ('audit.recorded')),
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

GRANT SELECT, INSERT, DELETE ON evento_salida TO identidad_servicio;
GRANT UPDATE (estado, intentos_publicacion, publicado_en, expira_en) ON evento_salida TO identidad_servicio;

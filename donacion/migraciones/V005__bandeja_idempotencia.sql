-- RedVital · db_donacion · V005 — Idempotencia, bandeja de salida y eventos procesados (DD 5.3.6, ADR-018)

-- Reconocimiento de reenvíos (EC-10). Única tabla de negocio con borrado físico.
CREATE TABLE operacion_idempotente (
    sujeto           VARCHAR(64) NOT NULL,   -- sub del token, u origen de red en operaciones públicas
    clave            VARCHAR(64) NOT NULL,   -- cabecera Idempotency-Key
    operacion        VARCHAR(80) NOT NULL,
    huella_peticion  VARCHAR(64) NOT NULL,   -- SHA-256 del cuerpo canónico
    recurso_id       UUID,
    codigo_estado    INTEGER     NOT NULL,
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en        TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (sujeto, clave)
);
CREATE INDEX ix_operacion_idempotente_expira ON operacion_idempotente(expira_en);

-- Bandeja de salida transaccional: el evento se escribe en la misma
-- transacción que el hecho. Un publicador del servicio la drena en orden.
CREATE TABLE evento_salida (
    id                    UUID PRIMARY KEY,
    secuencia             BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    tipo                  VARCHAR(80)  NOT NULL CHECK (tipo IN ('donation.completed', 'notice.requested')),
    version_esquema       INTEGER      NOT NULL CHECK (version_esquema > 0),
    tema                  VARCHAR(120) NOT NULL,
    clave                 VARCHAR(64)  NOT NULL,
    carga                 JSONB        NOT NULL,
    clave_natural         VARCHAR(160) UNIQUE,   -- IN-11: el mismo hecho no genera dos eventos
    correlacion_id        VARCHAR(36)  NOT NULL,
    estado                VARCHAR(20)  NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'publicado')),
    intentos_publicacion  INTEGER      NOT NULL DEFAULT 0,
    creado_en             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    publicado_en          TIMESTAMPTZ,
    expira_en             TIMESTAMPTZ,
    CONSTRAINT ck_evento_salida_publicado CHECK ((estado = 'publicado') = (publicado_en IS NOT NULL)),
    -- Una fila pendiente nunca vence.
    CONSTRAINT ck_evento_salida_expira CHECK (estado = 'publicado' OR expira_en IS NULL)
);
CREATE INDEX ix_evento_salida_pendiente ON evento_salida(secuencia) WHERE estado = 'pendiente';
CREATE INDEX ix_evento_salida_expira ON evento_salida(expira_en) WHERE expira_en IS NOT NULL;

-- Consumo idempotente: la fila y el efecto del evento van en una transacción.
CREATE TABLE evento_procesado (
    grupo_consumidor  VARCHAR(60) NOT NULL,
    evento_id         UUID        NOT NULL,
    tipo              VARCHAR(80) NOT NULL,
    procesado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en         TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (grupo_consumidor, evento_id)
);
CREATE INDEX ix_evento_procesado_expira ON evento_procesado(expira_en);

GRANT SELECT, INSERT, DELETE ON operacion_idempotente TO donacion_servicio;
GRANT SELECT, INSERT, DELETE ON evento_salida TO donacion_servicio;
GRANT UPDATE (estado, intentos_publicacion, publicado_en, expira_en) ON evento_salida TO donacion_servicio;
GRANT SELECT, INSERT, DELETE ON evento_procesado TO donacion_servicio;

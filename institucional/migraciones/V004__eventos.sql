-- RedVital · db_institucional · V004 — Comunicación con los demás servicios, solo por Kafka.
--
-- Institucional no llama a nadie ni recibe llamadas de otros servicios:
--   - publica cada alta o cambio de institución (EV-07, institution.changed)
--     por su bandeja de salida; Campañas y Donación guardan su propia copia;
--   - consume los agregados de M7 que publica Donación (EV-09,
--     indicators.updated) y los registros de auditoría de Identidad, Campañas y
--     Donación (EV-10, audit.recorded), y con ellos arma indicadores y bitácora.

-- Bandeja de salida: estructura común de toda base que publica (DD 5.3.6).
CREATE TABLE evento_salida (
    id                    UUID PRIMARY KEY,
    secuencia             BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
    tipo                  VARCHAR(80)  NOT NULL CHECK (tipo IN ('institution.changed')),
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

-- Eventos aplicados por el consumidor, grupo institucional.
CREATE TABLE evento_procesado (
    grupo_consumidor  VARCHAR(60) NOT NULL,
    evento_id         UUID        NOT NULL,
    tipo              VARCHAR(80) NOT NULL,
    procesado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en         TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (grupo_consumidor, evento_id)
);

-- M7: la última fotografía de cada institución (EV-09). Solo conteos.
CREATE TABLE captacion_diaria (
    institucion_id      UUID    NOT NULL,
    dia                 DATE    NOT NULL,
    donaciones          INTEGER NOT NULL CHECK (donaciones >= 0),
    unidades_generadas  INTEGER NOT NULL CHECK (unidades_generadas >= 0),
    unidades_no_aptas   INTEGER NOT NULL CHECK (unidades_no_aptas >= 0),
    unidades_vencidas   INTEGER NOT NULL CHECK (unidades_vencidas >= 0),
    PRIMARY KEY (institucion_id, dia)
);

CREATE TABLE existencia_agregada (
    institucion_id        UUID        NOT NULL,
    componente            VARCHAR(30) NOT NULL,
    grupo_sanguineo       VARCHAR(3)  NOT NULL,
    unidades_disponibles  INTEGER     NOT NULL CHECK (unidades_disponibles >= 0),
    unidades_por_vencer   INTEGER     NOT NULL CHECK (unidades_por_vencer >= 0),
    bajo_umbral           BOOLEAN     NOT NULL,
    PRIMARY KEY (institucion_id, componente, grupo_sanguineo)
);

-- Momento de la fotografía vigente: una más vieja que llegue tarde no la pisa.
CREATE TABLE indicador_recibido (
    institucion_id  UUID PRIMARY KEY,
    generado_en     TIMESTAMPTZ NOT NULL,
    recibido_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Bitácora: los registros de las series de los otros tres contextos (EV-10),
-- con la estructura común. La serie propia sigue en registro_auditoria_inst.
CREATE TABLE registro_bitacora (
    contexto                 VARCHAR(20) NOT NULL CHECK (contexto IN ('identidad', 'campanias', 'donacion')),
    id                       UUID        NOT NULL,
    actor_tipo               VARCHAR(20) NOT NULL CHECK (actor_tipo IN ('usuario', 'sistema', 'anonimo')),
    actor_id                 VARCHAR(64),
    rol                      VARCHAR(40),
    jurisdiccion_solicitada  VARCHAR(80),
    operacion                VARCHAR(80) NOT NULL,
    recurso_tipo             VARCHAR(40) NOT NULL,
    recurso_id               UUID,
    resultado                VARCHAR(20) NOT NULL CHECK (resultado IN ('permitido', 'denegado')),
    correlacion_id           VARCHAR(36) NOT NULL,
    origen                   VARCHAR(45),
    ocurrido_en              TIMESTAMPTZ NOT NULL,
    recibido_en              TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (contexto, id)
);
CREATE INDEX ix_registro_bitacora_ocurrido ON registro_bitacora(ocurrido_en DESC, id DESC);
CREATE INDEX ix_registro_bitacora_correlacion ON registro_bitacora(correlacion_id);

-- Solo anexado, como las series de las que sale.
CREATE TRIGGER tg_registro_bitacora_sin_modificacion
    BEFORE UPDATE OR DELETE ON registro_bitacora
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_auditoria_inst();
CREATE TRIGGER tg_registro_bitacora_sin_vaciado
    BEFORE TRUNCATE ON registro_bitacora
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_auditoria_inst();

-- Las instituciones que ya existían salen también por Kafka, una vez.
INSERT INTO evento_salida (id, tipo, version_esquema, tema, clave, carga, clave_natural, correlacion_id)
SELECT gen_random_uuid(), 'institution.changed', 1, 'redvital.institucional.institution-changed.v1', i.id::text,
       jsonb_build_object('institucion_id', i.id, 'codigo', i.codigo, 'nombre', i.nombre, 'tipo', i.tipo,
                          'territorio_codigo', t.codigo_divipola, 'territorio_ruta', t.ruta, 'vigente', i.vigente,
                          'cambiado_en', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
       'inicial:' || i.id, gen_random_uuid()::text
FROM institucion i JOIN territorio t ON t.id = i.territorio_id;

GRANT SELECT, INSERT, DELETE ON evento_salida TO institucional_servicio;
GRANT UPDATE (estado, intentos_publicacion, publicado_en, expira_en) ON evento_salida TO institucional_servicio;
GRANT SELECT, INSERT, DELETE ON evento_procesado TO institucional_servicio;
GRANT SELECT, INSERT, DELETE ON captacion_diaria TO institucional_servicio;
GRANT SELECT, INSERT, DELETE ON existencia_agregada TO institucional_servicio;
GRANT SELECT, INSERT, UPDATE ON indicador_recibido TO institucional_servicio;
GRANT SELECT, INSERT ON registro_bitacora TO institucional_servicio;

-- RedVital · db_donacion · V008 — Comunicación con el Servicio Institucional, solo por Kafka.
--
-- Donación ya no le pregunta nada a otro servicio:
--   - recibe las instituciones por EV-07 (institution.changed) y las guarda en
--     institucion_proyeccion, con la que resuelve la jurisdicción de U5, U6 y U7
--     y nombra el banco en el historial del donante;
--   - publica sus agregados de M7 por EV-09 (indicators.updated) y cada registro
--     de su bitácora por EV-10 (audit.recorded), desde la bandeja de salida.

ALTER TABLE evento_salida DROP CONSTRAINT evento_salida_tipo_check;
ALTER TABLE evento_salida ADD CONSTRAINT evento_salida_tipo_check
    CHECK (tipo IN ('donation.completed', 'notice.requested', 'indicators.updated', 'audit.recorded'));

CREATE TABLE institucion_proyeccion (
    institucion_id     UUID PRIMARY KEY,
    codigo             VARCHAR(20)  NOT NULL,
    nombre             VARCHAR(160) NOT NULL,
    tipo               VARCHAR(25)  NOT NULL CHECK (tipo IN ('banco_de_sangre', 'servicio_transfusion')),
    territorio_codigo  VARCHAR(5)   NOT NULL,
    territorio_ruta    VARCHAR(32)  NOT NULL,
    vigente            BOOLEAN      NOT NULL,
    -- Momento del cambio en Institucional: un evento más viejo no pisa uno más nuevo.
    cambiado_en        TIMESTAMPTZ  NOT NULL,
    evento_id          UUID         NOT NULL,
    actualizado_en     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_institucion_proyeccion_ruta ON institucion_proyeccion(territorio_ruta text_pattern_ops);

-- Huella de la última fotografía de M7 publicada por institución: sin cambios, no se republica.
CREATE TABLE indicador_publicado (
    institucion_id  UUID PRIMARY KEY,
    huella          VARCHAR(64) NOT NULL,
    publicado_en    TIMESTAMPTZ NOT NULL
);

GRANT SELECT, INSERT, UPDATE ON institucion_proyeccion TO donacion_servicio;
GRANT SELECT, INSERT, UPDATE ON indicador_publicado TO donacion_servicio;

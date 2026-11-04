-- RedVital · db_campana · V004 — Comunicación con el Servicio Institucional, solo por Kafka.
--
--   - Campañas recibe las instituciones por EV-07 (institution.changed) y las
--     guarda en institucion_proyeccion: al crear una campaña toma de ahí el
--     municipio y la ruta del banco, y el nombre del banco sale en el listado.
--   - Publica cada registro de su bitácora por EV-10 (audit.recorded).

ALTER TABLE evento_salida DROP CONSTRAINT evento_salida_tipo_check;
ALTER TABLE evento_salida ADD CONSTRAINT evento_salida_tipo_check
    CHECK (tipo IN ('campaign.published', 'audit.recorded'));

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
    actualizado_en     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON institucion_proyeccion TO campana_servicio;

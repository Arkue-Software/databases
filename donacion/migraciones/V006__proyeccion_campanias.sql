-- RedVital · db_donacion · V006 — Proyección local de campañas publicadas
--
-- Donación no consulta a Campañas por HTTP: toda comunicación entre los dos
-- servicios pasa por Kafka. Esta tabla es la proyección que Donación construye
-- al consumir redvital.campanias.campaign-published.v1 (EV-03) y la que usa
-- para confirmar la campaña al registrar una donación. No es copia de la
-- fuente de verdad: solo lo que Donación necesita para su propia decisión.

CREATE TABLE campania_publicada (
    campania_id        UUID PRIMARY KEY,
    institucion_id     UUID         NOT NULL,
    nombre             VARCHAR(160) NOT NULL,
    sede               VARCHAR(200) NOT NULL,
    territorio_codigo  VARCHAR(5)   NOT NULL,
    territorio_ruta    VARCHAR(32)  NOT NULL,
    inicia_en          TIMESTAMPTZ  NOT NULL,
    termina_en         TIMESTAMPTZ  NOT NULL,
    publicada_en       TIMESTAMPTZ  NOT NULL,
    -- Preparado para un evento de cierre (propuesta EV-08); hoy solo llega publicada.
    estado             VARCHAR(20)  NOT NULL DEFAULT 'publicada' CHECK (estado IN ('publicada', 'cerrada', 'cancelada')),
    evento_id          UUID         NOT NULL,
    actualizada_en     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_campania_publicada_fechas CHECK (termina_en > inicia_en)
);
CREATE INDEX ix_campania_publicada_institucion ON campania_publicada(institucion_id);
CREATE INDEX ix_campania_publicada_ruta ON campania_publicada(territorio_ruta);

GRANT SELECT, INSERT, UPDATE ON campania_publicada TO donacion_servicio;

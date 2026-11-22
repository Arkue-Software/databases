-- RedVital · db_donacion · V007 — Umbrales y alertas de inventario (DD 5.3.4, RF-19, RF-20)
-- Las existencias no se almacenan: se calculan sobre unidad filtrando por
-- estado_unidad.cuenta_disponible. El umbral es el único dato de inventario.

CREATE TABLE umbral_inventario (
    id                        UUID PRIMARY KEY,
    institucion_id            UUID        NOT NULL,
    componente_id             UUID        NOT NULL REFERENCES componente(id),
    grupo_sanguineo_id        UUID REFERENCES grupo_sanguineo(id),   -- nulo = cualquier grupo
    minimo_unidades           INTEGER     NOT NULL CHECK (minimo_unidades > 0),
    dias_previos_vencimiento  INTEGER     NOT NULL CHECK (dias_previos_vencimiento > 0),
    actualizado_por           UUID        NOT NULL,
    actualizado_en            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_umbral UNIQUE NULLS NOT DISTINCT (institucion_id, componente_id, grupo_sanguineo_id)
);

-- Una alerta no se borra al resolverse: se cierra.
CREATE TABLE alerta (
    id                  UUID PRIMARY KEY,
    tipo                VARCHAR(30) NOT NULL CHECK (tipo IN ('escasez', 'vencimiento_proximo')),
    institucion_id      UUID        NOT NULL,
    componente_id       UUID        NOT NULL REFERENCES componente(id),
    grupo_sanguineo_id  UUID REFERENCES grupo_sanguineo(id),
    unidad_id           UUID REFERENCES unidad(id),   -- solo en vencimiento próximo, que es por unidad
    valor_observado     INTEGER     NOT NULL,
    estado              VARCHAR(20) NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta', 'atendida', 'caducada')),
    generada_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    cerrada_en          TIMESTAMPTZ,
    atendida_por        UUID,                          -- nulo si la cerró el sistema
    CONSTRAINT ck_alerta_unidad CHECK ((tipo = 'vencimiento_proximo') = (unidad_id IS NOT NULL)),
    CONSTRAINT ck_alerta_cierre CHECK ((estado = 'abierta') = (cerrada_en IS NULL)),
    CONSTRAINT ck_alerta_atendida CHECK (estado = 'atendida' OR atendida_por IS NULL)
);
-- A lo sumo una alerta abierta por situación.
CREATE UNIQUE INDEX uq_alerta_abierta ON alerta (tipo, institucion_id, componente_id, grupo_sanguineo_id, unidad_id)
    NULLS NOT DISTINCT WHERE estado = 'abierta';
CREATE INDEX ix_alerta_institucion ON alerta(institucion_id, estado, generada_en DESC);

GRANT SELECT, INSERT ON umbral_inventario TO donacion_servicio;
GRANT UPDATE (minimo_unidades, dias_previos_vencimiento, actualizado_por, actualizado_en)
    ON umbral_inventario TO donacion_servicio;
GRANT SELECT, INSERT ON alerta TO donacion_servicio;
GRANT UPDATE (valor_observado, estado, cerrada_en, atendida_por) ON alerta TO donacion_servicio;

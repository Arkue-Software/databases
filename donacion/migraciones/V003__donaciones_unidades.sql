-- RedVital · db_donacion · V003 — Donaciones, unidades y su historial (DD 5.3.3)

CREATE TABLE donacion (
    id                UUID PRIMARY KEY,
    donante_id        UUID REFERENCES donante(id),               -- nulo en la donación anónima
    intencion_id      UUID UNIQUE REFERENCES intencion_donacion(id),
    tipo_donacion_id  UUID        NOT NULL REFERENCES tipo_donacion(id),
    institucion_id    UUID        NOT NULL,                       -- del token del operador, nunca del cuerpo
    campania_id       UUID,                                       -- db_campana, sin FK (IN-17)
    fecha_captacion   TIMESTAMPTZ NOT NULL,
    operador_id       UUID        NOT NULL,                       -- sub del operador
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- IN-07: donante e intención nunca coexisten.
    CONSTRAINT ck_donacion_donante_o_intencion CHECK (NOT (donante_id IS NOT NULL AND intencion_id IS NOT NULL))
);
CREATE INDEX ix_donacion_donante ON donacion(donante_id) WHERE donante_id IS NOT NULL;
CREATE INDEX ix_donacion_institucion ON donacion(institucion_id, fecha_captacion DESC);

CREATE TABLE unidad (
    id                       UUID PRIMARY KEY,
    donacion_id              UUID        NOT NULL REFERENCES donacion(id),
    componente_id            UUID        NOT NULL REFERENCES componente(id),
    grupo_sanguineo_id       UUID        NOT NULL REFERENCES grupo_sanguineo(id),
    institucion_custodia_id  UUID        NOT NULL,
    estado_id                UUID        NOT NULL REFERENCES estado_unidad(id),
    apta                     BOOLEAN,                -- único dato del resultado; no hay campo de causa (RI-02)
    fecha_vencimiento        DATE        NOT NULL,
    volumen_ml               INTEGER CHECK (volumen_ml IS NULL OR volumen_ml > 0),
    creado_en                TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_unidad_componente_por_donacion UNIQUE (donacion_id, componente_id)
);
CREATE INDEX ix_unidad_custodia_estado ON unidad(institucion_custodia_id, estado_id);
CREATE INDEX ix_unidad_estado_vencimiento ON unidad(estado_id, fecha_vencimiento);

CREATE TABLE evento_unidad (
    id                  UUID PRIMARY KEY,
    unidad_id           UUID        NOT NULL REFERENCES unidad(id),
    estado_anterior_id  UUID REFERENCES estado_unidad(id),          -- nulo solo en la creación
    estado_nuevo_id     UUID        NOT NULL REFERENCES estado_unidad(id),
    actor_tipo          VARCHAR(20) NOT NULL CHECK (actor_tipo IN ('usuario', 'sistema')),
    actor_id            VARCHAR(64),                                -- sub del usuario o nombre del proceso
    institucion_id      UUID        NOT NULL,
    observacion_id      UUID REFERENCES observacion_operativa(id),  -- nunca texto libre (D-02)
    correlacion_id      VARCHAR(36) NOT NULL,
    ocurrido_en         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_evento_unidad_unidad ON evento_unidad(unidad_id, ocurrido_en);

CREATE TABLE reconocimiento_donante (
    donante_id         UUID        NOT NULL REFERENCES donante(id),
    reconocimiento_id  UUID        NOT NULL REFERENCES reconocimiento(id),
    donacion_id        UUID        NOT NULL REFERENCES donacion(id),
    otorgado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (donante_id, reconocimiento_id)
);

-- Solo anexado: el historial de la unidad y los otorgamientos no se reescriben.
CREATE TRIGGER tg_evento_unidad_solo_anexado
    BEFORE UPDATE OR DELETE ON evento_unidad
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_solo_anexado();
CREATE TRIGGER tg_evento_unidad_sin_vaciado
    BEFORE TRUNCATE ON evento_unidad
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_solo_anexado();
CREATE TRIGGER tg_reconocimiento_donante_solo_anexado
    BEFORE UPDATE OR DELETE ON reconocimiento_donante
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_solo_anexado();
CREATE TRIGGER tg_reconocimiento_donante_sin_vaciado
    BEFORE TRUNCATE ON reconocimiento_donante
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_solo_anexado();

GRANT SELECT, INSERT ON donacion TO donacion_servicio;
GRANT SELECT, INSERT ON unidad TO donacion_servicio;
GRANT UPDATE (estado_id, apta, institucion_custodia_id, actualizado_en) ON unidad TO donacion_servicio;
GRANT SELECT, INSERT ON evento_unidad TO donacion_servicio;
GRANT SELECT, INSERT ON reconocimiento_donante TO donacion_servicio;

-- RedVital · db_donacion · V002 — Donantes, consentimientos e intenciones (DD 5.3.1, 5.3.2)

-- Función común de las tablas de solo anexado: bloquea UPDATE, DELETE y
-- TRUNCATE incluso al propietario. Un administrador con privilegios DDL puede
-- deshabilitarla; la inmutabilidad frente a administradores requiere un
-- destino externo e independiente.
CREATE FUNCTION impedir_modificacion_solo_anexado() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'La tabla % es de solo anexado: % no permitido', TG_TABLE_NAME, TG_OP;
END;
$$;

-- Perfil del donante registrado (U2). El donante anónimo no produce fila.
CREATE TABLE donante (
    id                     UUID PRIMARY KEY,
    usuario_id             UUID         NOT NULL UNIQUE,   -- sub del token; cuenta en db_identidad, sin FK (IN-17)
    documento_hash         VARCHAR(64)  NOT NULL UNIQUE,   -- HMAC-SHA256 del documento, nunca el documento
    nombre                 VARCHAR(120) NOT NULL,
    correo                 VARCHAR(160),                   -- contacto para avisos, distinto del correo de acceso
    telefono               VARCHAR(20),
    fecha_nacimiento       DATE         NOT NULL,
    municipio_ruta         VARCHAR(32),
    grupo_sanguineo_id     UUID REFERENCES grupo_sanguineo(id), -- tipificado en la primera donación
    fecha_ultima_donacion  DATE,
    elegible_desde         DATE,
    activo                 BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_donante_documento_hash CHECK (documento_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_donante_municipio_ruta CHECK (municipio_ruta IS NULL OR municipio_ruta ~ '^/00/[0-9]{2}/[0-9]{5}$')
);

-- Autorización por finalidad (Ley 1581). Historia, no estado: revocar agrega.
CREATE TABLE consentimiento (
    id             UUID PRIMARY KEY,
    donante_id     UUID        NOT NULL REFERENCES donante(id),
    finalidad      VARCHAR(40) NOT NULL CHECK (finalidad IN ('tratamiento_datos', 'avisos_campanas')),
    version_aviso  VARCHAR(20) NOT NULL,
    otorgado       BOOLEAN     NOT NULL,
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_consentimiento_vigente ON consentimiento(donante_id, finalidad, creado_en DESC);

CREATE TRIGGER tg_consentimiento_solo_anexado
    BEFORE UPDATE OR DELETE ON consentimiento
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_solo_anexado();
CREATE TRIGGER tg_consentimiento_sin_vaciado
    BEFORE TRUNCATE ON consentimiento
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_solo_anexado();

-- Registro anónimo (RF-01, EC-17). Sin nombre, documento, correo ni
-- teléfono: esa ausencia es literalmente el cumplimiento de EC-17.
CREATE TABLE intencion_donacion (
    id                  UUID PRIMARY KEY,
    codigo              VARCHAR(12) NOT NULL UNIQUE,
    grupo_sanguineo_id  UUID REFERENCES grupo_sanguineo(id),  -- autodeclarado, no confiable
    municipio_ruta      VARCHAR(32),
    estado              VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'atendida', 'caducada')),
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en           TIMESTAMPTZ NOT NULL,
    atendida_en         TIMESTAMPTZ,
    -- Doce caracteres de un alfabeto sin caracteres ambiguos (31 símbolos).
    CONSTRAINT ck_intencion_codigo CHECK (codigo ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{12}$'),
    CONSTRAINT ck_intencion_vigencia CHECK (expira_en > creado_en AND expira_en <= creado_en + INTERVAL '30 days'),
    CONSTRAINT ck_intencion_atendida CHECK ((estado = 'atendida') = (atendida_en IS NOT NULL)),
    CONSTRAINT ck_intencion_municipio_ruta CHECK (municipio_ruta IS NULL OR municipio_ruta ~ '^/00/[0-9]{2}/[0-9]{5}$')
);

GRANT SELECT, INSERT ON donante TO donacion_servicio;
GRANT UPDATE (nombre, correo, telefono, municipio_ruta, grupo_sanguineo_id,
              fecha_ultima_donacion, elegible_desde, activo, actualizado_en)
    ON donante TO donacion_servicio;
GRANT SELECT, INSERT ON consentimiento TO donacion_servicio;
GRANT SELECT, INSERT ON intencion_donacion TO donacion_servicio;
GRANT UPDATE (estado, atendida_en) ON intencion_donacion TO donacion_servicio;

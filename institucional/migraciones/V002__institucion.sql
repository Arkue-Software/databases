-- RedVital · db_institucional · V002 — Registro de instituciones (RF-09, EC-39, EC-42).
-- Banco de sangre (capta y custodia unidades) o servicio de transfusión (no
-- custodia), adscrito a un municipio. Una institución dada de baja deja de
-- figurar en los listados; las referencias que otros servicios guardan a su
-- id siguen siendo válidas, por eso no existe borrado físico (IN-18).

CREATE TABLE institucion (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo         VARCHAR(20)  NOT NULL UNIQUE,      -- código de habilitación del prestador
    nombre         VARCHAR(160) NOT NULL,
    tipo           VARCHAR(25)  NOT NULL CHECK (tipo IN ('banco_de_sangre', 'servicio_transfusion')),
    territorio_id  UUID NOT NULL REFERENCES territorio(id),
    direccion      VARCHAR(200),
    vigente        BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),  -- EC-42: nada anterior se le atribuye
    creado_por     UUID NOT NULL,                        -- usuario que la dio de alta (referencia lógica)
    CONSTRAINT ck_institucion_codigo CHECK (codigo ~ '^[A-Za-z0-9-]{4,20}$'),
    CONSTRAINT ck_institucion_nombre CHECK (length(btrim(nombre)) > 0)
);
CREATE INDEX ix_institucion_territorio ON institucion(territorio_id);

-- Una institución pertenece a un municipio, y su tipo no cambia: otros
-- servicios ya decidieron sobre él (custodia de unidades, EC-39).
CREATE FUNCTION validar_institucion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT nivel FROM territorio WHERE id = NEW.territorio_id) <> 'municipal' THEN
        RAISE EXCEPTION 'La institución % debe pertenecer a un municipio', NEW.codigo
            USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.tipo <> OLD.tipo THEN
        RAISE EXCEPTION 'El tipo de la institución % no cambia', OLD.codigo
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_institucion_validar
    BEFORE INSERT OR UPDATE ON institucion
    FOR EACH ROW EXECUTE FUNCTION validar_institucion();

GRANT SELECT ON institucion TO institucional_servicio;
GRANT INSERT (id, codigo, nombre, tipo, territorio_id, direccion, creado_por) ON institucion TO institucional_servicio;
GRANT UPDATE (nombre, direccion, vigente) ON institucion TO institucional_servicio;

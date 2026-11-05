-- RedVital · db_institucional · V003 — Serie de auditoría del contexto institucional (ADR-016).
-- Registra el alta, la baja y el cambio de territorios e instituciones (EC-42),
-- cada consulta de la bitácora y las denegaciones F3 del contexto (Tabla 16).
-- El registro evita almacenar el contenido del recurso y admite solo
-- inserciones del rol de servicio. El trigger previene cambios accidentales;
-- el propietario de migraciones y el superusuario siguen siendo roles de
-- confianza administrativa y no constituyen una garantía antimanipulación.

CREATE TABLE registro_auditoria_inst (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    ocurrido_en              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_auditoria_inst_anonimo_sin_actor CHECK (
        actor_tipo <> 'anonimo' OR actor_id IS NULL
    )
);

CREATE INDEX ix_auditoria_inst_correlacion ON registro_auditoria_inst(correlacion_id);
CREATE INDEX ix_auditoria_inst_ocurrido ON registro_auditoria_inst(ocurrido_en);

GRANT SELECT, INSERT ON registro_auditoria_inst TO institucional_servicio;

CREATE FUNCTION impedir_modificacion_auditoria_inst() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'La bitácora es append-only: % no permitido sobre %', TG_OP, TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER tg_auditoria_inst_sin_modificacion
    BEFORE UPDATE OR DELETE ON registro_auditoria_inst
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_auditoria_inst();

CREATE TRIGGER tg_auditoria_inst_sin_vaciado
    BEFORE TRUNCATE ON registro_auditoria_inst
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_auditoria_inst();

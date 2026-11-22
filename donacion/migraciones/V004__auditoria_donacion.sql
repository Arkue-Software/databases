-- RedVital · db_donacion · V004 — Serie de auditoría del contexto de donación (ADR-016)
-- Estructura común de las cuatro series. No existe campo para el contenido
-- del recurso: se registra que se intentó, nunca el dato.

CREATE TABLE registro_auditoria (
    id                       UUID PRIMARY KEY,
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
    CONSTRAINT ck_auditoria_anonimo_sin_actor CHECK (actor_tipo <> 'anonimo' OR actor_id IS NULL)
);
CREATE INDEX ix_auditoria_donacion_correlacion ON registro_auditoria(correlacion_id);
CREATE INDEX ix_auditoria_donacion_ocurrido    ON registro_auditoria(ocurrido_en);
CREATE INDEX ix_auditoria_donacion_recurso     ON registro_auditoria(recurso_tipo, recurso_id);

CREATE TRIGGER tg_auditoria_donacion_sin_modificacion
    BEFORE UPDATE OR DELETE ON registro_auditoria
    FOR EACH ROW EXECUTE FUNCTION impedir_modificacion_solo_anexado();
CREATE TRIGGER tg_auditoria_donacion_sin_vaciado
    BEFORE TRUNCATE ON registro_auditoria
    FOR EACH STATEMENT EXECUTE FUNCTION impedir_modificacion_solo_anexado();

GRANT SELECT, INSERT ON registro_auditoria TO donacion_servicio;

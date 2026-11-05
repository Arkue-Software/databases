-- RedVital · db_identidad · V004 — Alta de cuentas de donante desde Donación
-- POST /v1/donantes (Servicio de Donación) crea el perfil y pide aquí la cuenta
-- por la operación interna /internal/v1/cuentas-donante. La clave de
-- idempotencia hace que el reintento de un registro devuelva la misma cuenta
-- en lugar de crear otra o fallar (EC-10).

CREATE TABLE operacion_idempotente (
    sujeto           VARCHAR(64) NOT NULL,   -- cliente de servicio que llama
    clave            VARCHAR(64) NOT NULL,   -- cabecera Idempotency-Key
    operacion        VARCHAR(80) NOT NULL,
    huella_peticion  VARCHAR(64) NOT NULL,   -- SHA-256 del correo y el nombre; nunca de la credencial
    recurso_id       UUID        NOT NULL,
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en        TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (sujeto, clave)
);
CREATE INDEX ix_operacion_idempotente_expira ON operacion_idempotente(expira_en);

GRANT SELECT, INSERT, DELETE ON operacion_idempotente TO identidad_servicio;

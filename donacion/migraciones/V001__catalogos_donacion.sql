-- RedVital · db_donacion · V001 — Catálogos (DD V3.0, Tabla 10)
-- Lo aplica Flyway como donacion_propietario. Una migración aplicada NUNCA se
-- edita: los cambios van en una versión nueva.
--
-- Los identificadores de catálogo son fijos para que el conjunto sintético y
-- las pruebas puedan referirlos. La aplicación expone siempre los códigos.

CREATE TABLE tipo_donacion (
    id       UUID PRIMARY KEY,
    codigo   VARCHAR(40) NOT NULL UNIQUE,
    nombre   VARCHAR(80) NOT NULL,
    vigente  BOOLEAN     NOT NULL DEFAULT TRUE
);
-- Un único valor: es lo que hace verificable EC-24 sin construir nada (ADR-012).
INSERT INTO tipo_donacion (id, codigo, nombre) VALUES
    ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'sangre_total', 'Sangre total');

-- La vida útil es dato y no constante: corregirla no exige desplegar.
CREATE TABLE componente (
    id                UUID PRIMARY KEY,
    codigo            VARCHAR(40) NOT NULL UNIQUE,
    nombre            VARCHAR(80) NOT NULL,
    vida_util_dias    INTEGER     NOT NULL CHECK (vida_util_dias > 0),
    tipo_donacion_id  UUID        NOT NULL REFERENCES tipo_donacion(id)
);
INSERT INTO componente (id, codigo, nombre, vida_util_dias, tipo_donacion_id) VALUES
    ('c0a00000-0000-4000-8000-000000000001', 'globulos_rojos', 'Glóbulos rojos', 42,  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'),
    ('c0a00000-0000-4000-8000-000000000002', 'plasma',         'Plasma',         365, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'),
    ('c0a00000-0000-4000-8000-000000000003', 'plaquetas',      'Plaquetas',      5,   'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');

CREATE TABLE grupo_sanguineo (
    id      UUID PRIMARY KEY,
    abo     VARCHAR(2) NOT NULL CHECK (abo IN ('O', 'A', 'B', 'AB')),
    rh      VARCHAR(1) NOT NULL CHECK (rh IN ('+', '-')),
    codigo  VARCHAR(3) NOT NULL UNIQUE,
    CONSTRAINT uq_grupo_abo_rh UNIQUE (abo, rh),
    CONSTRAINT ck_grupo_codigo CHECK (codigo = abo || rh)
);
INSERT INTO grupo_sanguineo (id, abo, rh, codigo) VALUES
    ('d0a00000-0000-4000-8000-000000000001', 'O',  '+', 'O+'),
    ('d0a00000-0000-4000-8000-000000000002', 'O',  '-', 'O-'),
    ('d0a00000-0000-4000-8000-000000000003', 'A',  '+', 'A+'),
    ('d0a00000-0000-4000-8000-000000000004', 'A',  '-', 'A-'),
    ('d0a00000-0000-4000-8000-000000000005', 'B',  '+', 'B+'),
    ('d0a00000-0000-4000-8000-000000000006', 'B',  '-', 'B-'),
    ('d0a00000-0000-4000-8000-000000000007', 'AB', '+', 'AB+'),
    ('d0a00000-0000-4000-8000-000000000008', 'AB', '-', 'AB-');

-- Tabla 11 del DD, validada por el cliente (D-04). Se genera por reglas en
-- lugar de escribir las 90 filas: 27 de glóbulos rojos, 36 de plasma y 27 de
-- plaquetas. Toda combinación ausente es incompatible.
CREATE TABLE compatibilidad (
    componente_id      UUID NOT NULL REFERENCES componente(id),
    grupo_donante_id   UUID NOT NULL REFERENCES grupo_sanguineo(id),
    grupo_receptor_id  UUID NOT NULL REFERENCES grupo_sanguineo(id),
    PRIMARY KEY (componente_id, grupo_donante_id, grupo_receptor_id)
);
INSERT INTO compatibilidad (componente_id, grupo_donante_id, grupo_receptor_id)
SELECT c.id, d.id, r.id
FROM componente c
CROSS JOIN grupo_sanguineo d
CROSS JOIN grupo_sanguineo r
WHERE
    -- Glóbulos rojos: el receptor debe aceptar el ABO y el Rh del donante.
    (c.codigo = 'globulos_rojos'
        AND (d.abo = 'O' OR d.abo = r.abo OR r.abo = 'AB')
        AND (d.rh = '-' OR r.rh = '+'))
    -- Plasma: regla inversa, sin restricción de Rh.
 OR (c.codigo = 'plasma'
        AND (d.abo = 'AB' OR d.abo = r.abo OR r.abo = 'O'))
    -- Plaquetas: ABO según la regla del plasma; donante Rh+ solo a receptor Rh+.
 OR (c.codigo = 'plaquetas'
        AND (d.abo = 'AB' OR d.abo = r.abo OR r.abo = 'O')
        AND (d.rh = '-' OR r.rh = '+'));

-- Nueve estados (DD, sección 10). cuenta_disponible es la única fuente de
-- EC-12: toda consulta de existencias filtra por esta columna.
CREATE TABLE estado_unidad (
    id                 UUID PRIMARY KEY,
    codigo             VARCHAR(40) NOT NULL UNIQUE,
    nombre             VARCHAR(80) NOT NULL,
    es_terminal        BOOLEAN     NOT NULL DEFAULT FALSE,
    cuenta_disponible  BOOLEAN     NOT NULL DEFAULT FALSE
);
INSERT INTO estado_unidad (id, codigo, nombre, es_terminal, cuenta_disponible) VALUES
    ('b1a20001-0000-0000-0000-000000000001', 'captada',     'Captada',     FALSE, FALSE),
    ('b1a20002-0000-0000-0000-000000000002', 'fraccionada', 'Fraccionada', FALSE, FALSE),
    ('b1a20003-0000-0000-0000-000000000003', 'en_tamizaje', 'En tamizaje', FALSE, FALSE),
    ('b1a20004-0000-0000-0000-000000000004', 'disponible',  'Disponible',  FALSE, TRUE),
    ('b1a20005-0000-0000-0000-000000000005', 'reservada',   'Reservada',   FALSE, FALSE),
    ('b1a20006-0000-0000-0000-000000000006', 'despachada',  'Despachada',  TRUE,  FALSE),
    ('b1a20007-0000-0000-0000-000000000007', 'no_apta',     'No apta',     FALSE, FALSE),
    ('b1a20008-0000-0000-0000-000000000008', 'vencida',     'Vencida',     FALSE, FALSE),
    ('b1a20009-0000-0000-0000-000000000009', 'desechada',   'Desechada',   TRUE,  FALSE);

-- Matriz cerrada (DD, Tabla 20): trece transiciones válidas. Toda transición
-- ausente está prohibida (EC-04). El número es el de la tabla del DD.
CREATE TABLE transicion_valida (
    numero             SMALLINT    PRIMARY KEY CHECK (numero BETWEEN 1 AND 13),
    estado_origen_id   UUID        NOT NULL REFERENCES estado_unidad(id),
    estado_destino_id  UUID        NOT NULL REFERENCES estado_unidad(id),
    actor_tipo         VARCHAR(20) NOT NULL CHECK (actor_tipo IN ('usuario', 'sistema')),
    operacion          VARCHAR(120) NOT NULL,
    CONSTRAINT uq_transicion UNIQUE (estado_origen_id, estado_destino_id, actor_tipo),
    CONSTRAINT ck_transicion_cambia_estado CHECK (estado_origen_id <> estado_destino_id)
);
INSERT INTO transicion_valida (numero, estado_origen_id, estado_destino_id, actor_tipo, operacion)
SELECT t.numero, o.id, d.id, t.actor, t.operacion
FROM (VALUES
    (1,  'captada',     'fraccionada', 'usuario', 'POST /v1/donaciones/{id}/fraccionamiento'),
    (2,  'fraccionada', 'en_tamizaje', 'usuario', 'POST /v1/unidades/{id}/ingreso-tamizaje'),
    (3,  'en_tamizaje', 'disponible',  'usuario', 'POST /v1/unidades/{id}/tamizaje (apta verdadero)'),
    (4,  'en_tamizaje', 'no_apta',     'usuario', 'POST /v1/unidades/{id}/tamizaje (apta falso)'),
    (5,  'disponible',  'reservada',   'usuario', 'POST /v1/unidades/{id}/reserva'),
    (6,  'reservada',   'disponible',  'usuario', 'DELETE /v1/unidades/{id}/reserva'),
    (7,  'reservada',   'despachada',  'usuario', 'POST /v1/unidades/{id}/despacho'),
    (8,  'disponible',  'vencida',     'sistema', 'Proceso de vencimiento'),
    (9,  'reservada',   'vencida',     'sistema', 'Proceso de vencimiento'),
    (10, 'fraccionada', 'vencida',     'sistema', 'Proceso de vencimiento'),
    (11, 'en_tamizaje', 'vencida',     'sistema', 'Proceso de vencimiento'),
    (12, 'no_apta',     'desechada',   'usuario', 'POST /v1/unidades/{id}/disposicion-final'),
    (13, 'vencida',     'desechada',   'usuario', 'POST /v1/unidades/{id}/disposicion-final')
) AS t(numero, origen, destino, actor, operacion)
JOIN estado_unidad o ON o.codigo = t.origen
JOIN estado_unidad d ON d.codigo = t.destino;

-- Anotaciones operativas cerradas (D-02). Ningún código describe una
-- condición del donante ni de la unidad: no existe texto libre.
CREATE TABLE observacion_operativa (
    id       UUID PRIMARY KEY,
    codigo   VARCHAR(40) NOT NULL UNIQUE,
    nombre   VARCHAR(80) NOT NULL,
    vigente  BOOLEAN     NOT NULL DEFAULT TRUE
);
INSERT INTO observacion_operativa (id, codigo, nombre) VALUES
    ('e0a00000-0000-4000-8000-000000000001', 'traslado_interno',        'Traslado interno'),
    ('e0a00000-0000-4000-8000-000000000002', 'reetiquetado',            'Reetiquetado'),
    ('e0a00000-0000-4000-8000-000000000003', 'control_temperatura',     'Control de temperatura'),
    ('e0a00000-0000-4000-8000-000000000004', 'empaque_envio',           'Empaque para envío'),
    ('e0a00000-0000-4000-8000-000000000005', 'recepcion_conforme',      'Recepción conforme'),
    ('e0a00000-0000-4000-8000-000000000006', 'verificacion_inventario', 'Verificación de inventario');

-- Reconocimientos (RF-11). Sin ningún atributo de valor, saldo ni canje: esa
-- ausencia es el cumplimiento del Decreto 1571 de 1993 (RNI-02, EC-14).
CREATE TABLE reconocimiento (
    id                   UUID PRIMARY KEY,
    codigo               VARCHAR(40)  NOT NULL UNIQUE,
    nombre               VARCHAR(80)  NOT NULL,
    descripcion          VARCHAR(280) NOT NULL,
    criterio_donaciones  INTEGER      NOT NULL UNIQUE CHECK (criterio_donaciones > 0),
    orden                INTEGER      NOT NULL UNIQUE,
    vigente              BOOLEAN      NOT NULL DEFAULT TRUE
);
INSERT INTO reconocimiento (id, codigo, nombre, descripcion, criterio_donaciones, orden) VALUES
    ('f0a00000-0000-4000-8000-000000000001', 'primera_donacion',  'Primera donación',  'Gracias por dar el primer paso.',                                   1,  1),
    ('f0a00000-0000-4000-8000-000000000002', 'tres_donaciones',   'Tres donaciones',   'Has donado tres veces. Gracias por volver.',                        3,  2),
    ('f0a00000-0000-4000-8000-000000000003', 'donante_constante', 'Donante constante', 'Cinco donaciones registradas. Tu constancia sostiene la reserva.',   5,  3),
    ('f0a00000-0000-4000-8000-000000000004', 'diez_donaciones',   'Diez donaciones',   'Diez veces has vuelto. Gracias, de verdad.',                         10, 4);

GRANT SELECT ON tipo_donacion, componente, grupo_sanguineo, compatibilidad,
                estado_unidad, transicion_valida, observacion_operativa, reconocimiento
    TO donacion_servicio;

-- RedVital · db_institucional · V001 — Jerarquía territorial (RF-09, DD Sección 7).
-- Tres niveles: nacional (raíz única), departamental y municipal. La ruta se
-- deriva del código DIVIPOLA por la regla fija de IN-13 y la base la impone:
-- /00, /00/05, /00/05/05001. Con ella, «¿está dentro de mi jurisdicción?» es
-- una comparación de prefijo que cualquier servicio resuelve localmente.
--
-- La geografía es real y pública: se carga en todo ambiente. Versión
-- 2026.10-parcial, la misma de la web (src/shared/datos/divipola.ts): los 33
-- departamentos y las capitales con los municipios más poblados. Los demás
-- municipios los da de alta el administrador nacional (POST /v1/territorios).

CREATE FUNCTION ruta_divipola(codigo TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT CASE
        WHEN codigo = '00' THEN '/00'
        WHEN codigo ~ '^[0-9]{2}$' THEN '/00/' || codigo
        WHEN codigo ~ '^[0-9]{5}$' THEN '/00/' || substr(codigo, 1, 2) || '/' || codigo
    END
$$;

CREATE TABLE territorio (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo_divipola  VARCHAR(5)   NOT NULL UNIQUE,
    nombre           VARCHAR(120) NOT NULL,
    nivel            VARCHAR(15)  NOT NULL CHECK (nivel IN ('nacional', 'departamental', 'municipal')),
    padre_id         UUID REFERENCES territorio(id),
    ruta             VARCHAR(32)  NOT NULL UNIQUE,
    vigente          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_territorio_nombre CHECK (length(btrim(nombre)) > 0),
    -- IN-13: la ruta es exactamente la derivada del código…
    CONSTRAINT ck_territorio_ruta CHECK (ruta = ruta_divipola(codigo_divipola)),
    -- …el código corresponde al nivel…
    CONSTRAINT ck_territorio_codigo_nivel CHECK (
        (nivel = 'nacional' AND codigo_divipola = '00') OR
        (nivel = 'departamental' AND codigo_divipola ~ '^[0-9]{2}$' AND codigo_divipola <> '00') OR
        (nivel = 'municipal' AND codigo_divipola ~ '^[0-9]{5}$')),
    -- …y solo el nivel nacional no tiene padre.
    CONSTRAINT ck_territorio_padre CHECK ((nivel = 'nacional') = (padre_id IS NULL))
);
-- Raíz única.
CREATE UNIQUE INDEX ux_territorio_raiz ON territorio ((padre_id IS NULL)) WHERE padre_id IS NULL;
CREATE INDEX ix_territorio_padre ON territorio(padre_id);
CREATE INDEX ix_territorio_ruta ON territorio(ruta text_pattern_ops);

-- El padre es el nivel inmediato superior y su ruta es el prefijo de la propia.
CREATE FUNCTION validar_padre_territorio() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    p territorio%ROWTYPE;
BEGIN
    IF NEW.padre_id IS NULL THEN
        RETURN NEW;
    END IF;
    SELECT * INTO p FROM territorio WHERE id = NEW.padre_id;
    IF NOT ((NEW.nivel = 'departamental' AND p.nivel = 'nacional') OR
            (NEW.nivel = 'municipal' AND p.nivel = 'departamental' AND NEW.ruta LIKE p.ruta || '/%')) THEN
        RAISE EXCEPTION 'El territorio % no puede depender de %', NEW.codigo_divipola, p.codigo_divipola
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_territorio_padre
    BEFORE INSERT OR UPDATE OF padre_id, nivel, codigo_divipola ON territorio
    FOR EACH ROW EXECUTE FUNCTION validar_padre_territorio();

INSERT INTO territorio (codigo_divipola, nombre, nivel, ruta)
VALUES ('00', 'Colombia', 'nacional', '/00');

INSERT INTO territorio (codigo_divipola, nombre, nivel, padre_id, ruta)
SELECT d.codigo, d.nombre, 'departamental', (SELECT id FROM territorio WHERE codigo_divipola = '00'), ruta_divipola(d.codigo)
FROM (VALUES
    ('05', 'Antioquia'),
    ('08', 'Atlántico'),
    ('11', 'Bogotá, D.C.'),
    ('13', 'Bolívar'),
    ('15', 'Boyacá'),
    ('17', 'Caldas'),
    ('18', 'Caquetá'),
    ('19', 'Cauca'),
    ('20', 'Cesar'),
    ('23', 'Córdoba'),
    ('25', 'Cundinamarca'),
    ('27', 'Chocó'),
    ('41', 'Huila'),
    ('44', 'La Guajira'),
    ('47', 'Magdalena'),
    ('50', 'Meta'),
    ('52', 'Nariño'),
    ('54', 'Norte de Santander'),
    ('63', 'Quindío'),
    ('66', 'Risaralda'),
    ('68', 'Santander'),
    ('70', 'Sucre'),
    ('73', 'Tolima'),
    ('76', 'Valle del Cauca'),
    ('81', 'Arauca'),
    ('85', 'Casanare'),
    ('86', 'Putumayo'),
    ('88', 'Archipiélago de San Andrés, Providencia y Santa Catalina'),
    ('91', 'Amazonas'),
    ('94', 'Guainía'),
    ('95', 'Guaviare'),
    ('97', 'Vaupés'),
    ('99', 'Vichada')
) AS d(codigo, nombre);

INSERT INTO territorio (codigo_divipola, nombre, nivel, padre_id, ruta)
SELECT m.codigo, m.nombre, 'municipal', p.id, ruta_divipola(m.codigo)
FROM (VALUES
    ('05001', 'Medellín'),
    ('05045', 'Apartadó'),
    ('05088', 'Bello'),
    ('05266', 'Envigado'),
    ('05360', 'Itagüí'),
    ('05615', 'Rionegro'),
    ('05631', 'Sabaneta'),
    ('08001', 'Barranquilla'),
    ('08433', 'Malambo'),
    ('08573', 'Puerto Colombia'),
    ('08758', 'Soledad'),
    ('11001', 'Bogotá, D.C.'),
    ('13001', 'Cartagena de Indias'),
    ('13430', 'Magangué'),
    ('13836', 'Turbaco'),
    ('15001', 'Tunja'),
    ('15176', 'Chiquinquirá'),
    ('15238', 'Duitama'),
    ('15759', 'Sogamoso'),
    ('17001', 'Manizales'),
    ('17380', 'La Dorada'),
    ('18001', 'Florencia'),
    ('19001', 'Popayán'),
    ('19698', 'Santander de Quilichao'),
    ('20001', 'Valledupar'),
    ('20011', 'Aguachica'),
    ('23001', 'Montería'),
    ('23162', 'Cereté'),
    ('23417', 'Santa Cruz de Lorica'),
    ('25175', 'Chía'),
    ('25269', 'Facatativá'),
    ('25290', 'Fusagasugá'),
    ('25307', 'Girardot'),
    ('25754', 'Soacha'),
    ('25899', 'Zipaquirá'),
    ('27001', 'Quibdó'),
    ('41001', 'Neiva'),
    ('41298', 'Garzón'),
    ('41551', 'Pitalito'),
    ('44001', 'Riohacha'),
    ('44430', 'Maicao'),
    ('47001', 'Santa Marta'),
    ('47189', 'Ciénaga'),
    ('50001', 'Villavicencio'),
    ('50006', 'Acacías'),
    ('50313', 'Granada'),
    ('52001', 'Pasto'),
    ('52356', 'Ipiales'),
    ('52835', 'San Andrés de Tumaco'),
    ('54001', 'Cúcuta'),
    ('54498', 'Ocaña'),
    ('54518', 'Pamplona'),
    ('54874', 'Villa del Rosario'),
    ('63001', 'Armenia'),
    ('63130', 'Calarcá'),
    ('66001', 'Pereira'),
    ('66170', 'Dosquebradas'),
    ('66682', 'Santa Rosa de Cabal'),
    ('68001', 'Bucaramanga'),
    ('68081', 'Barrancabermeja'),
    ('68276', 'Floridablanca'),
    ('68307', 'Girón'),
    ('68547', 'Piedecuesta'),
    ('70001', 'Sincelejo'),
    ('70215', 'Corozal'),
    ('73001', 'Ibagué'),
    ('73268', 'Espinal'),
    ('76001', 'Cali'),
    ('76109', 'Buenaventura'),
    ('76111', 'Guadalajara de Buga'),
    ('76147', 'Cartago'),
    ('76364', 'Jamundí'),
    ('76520', 'Palmira'),
    ('76834', 'Tuluá'),
    ('76892', 'Yumbo'),
    ('81001', 'Arauca'),
    ('81736', 'Saravena'),
    ('85001', 'Yopal'),
    ('85010', 'Aguazul'),
    ('86001', 'Mocoa'),
    ('86568', 'Puerto Asís'),
    ('88001', 'San Andrés'),
    ('88564', 'Providencia'),
    ('91001', 'Leticia'),
    ('94001', 'Inírida'),
    ('95001', 'San José del Guaviare'),
    ('97001', 'Mitú'),
    ('99001', 'Puerto Carreño')
) AS m(codigo, nombre)
JOIN territorio p ON p.codigo_divipola = substr(m.codigo, 1, 2);

-- El nombre y la vigencia son lo único modificable: código, nivel, padre y
-- ruta son la identidad del territorio y otros servicios ya guardan su ruta.
GRANT SELECT ON territorio TO institucional_servicio;
GRANT INSERT (id, codigo_divipola, nombre, nivel, padre_id, ruta) ON territorio TO institucional_servicio;
GRANT UPDATE (nombre, vigente) ON territorio TO institucional_servicio;

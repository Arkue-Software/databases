-- RedVital · databases/donacion/00_roles.sql
-- Mismo patrón que identidad/00_roles.sql. Lo ejecuta una vez el superusuario.
\set ON_ERROR_STOP on

SELECT format('CREATE ROLE donacion_propietario LOGIN PASSWORD %L', :'password_propietario')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'donacion_propietario') \gexec

SELECT format('CREATE ROLE donacion_servicio LOGIN PASSWORD %L NOCREATEDB NOCREATEROLE', :'password_servicio')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'donacion_servicio') \gexec

ALTER DATABASE db_donacion OWNER TO donacion_propietario;
ALTER SCHEMA public OWNER TO donacion_propietario;

REVOKE ALL ON DATABASE db_donacion FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE db_donacion TO donacion_servicio;
GRANT USAGE ON SCHEMA public TO donacion_servicio;

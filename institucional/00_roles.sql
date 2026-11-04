-- RedVital · databases/institucional/00_roles.sql
-- Mismo patrón que campanas/00_roles.sql. Lo ejecuta una vez el superusuario.
\set ON_ERROR_STOP on

SELECT format('CREATE ROLE institucional_propietario LOGIN PASSWORD %L', :'password_propietario')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'institucional_propietario') \gexec

SELECT format('CREATE ROLE institucional_servicio LOGIN PASSWORD %L NOCREATEDB NOCREATEROLE', :'password_servicio')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'institucional_servicio') \gexec

ALTER DATABASE db_institucional OWNER TO institucional_propietario;
ALTER SCHEMA public OWNER TO institucional_propietario;

REVOKE ALL ON DATABASE db_institucional FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE db_institucional TO institucional_servicio;
GRANT USAGE ON SCHEMA public TO institucional_servicio;

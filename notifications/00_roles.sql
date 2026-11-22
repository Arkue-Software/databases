-- RedVital · databases/notifications/00_roles.sql
-- Lo ejecuta una vez el superusuario durante la inicialización de PostgreSQL.
\set ON_ERROR_STOP on

SELECT format('CREATE ROLE notifications_propietario LOGIN PASSWORD %L NOCREATEDB NOCREATEROLE', :'password_propietario')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'notifications_propietario') \gexec

SELECT format('CREATE ROLE notifications_servicio LOGIN PASSWORD %L NOCREATEDB NOCREATEROLE', :'password_servicio')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'notifications_servicio') \gexec

-- Las migraciones históricas otorgan permisos a estos grupos sin inicio de sesión.
SELECT 'CREATE ROLE notifications_app NOLOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'notifications_app') \gexec

SELECT 'CREATE ROLE notifications_read_only NOLOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'notifications_read_only') \gexec

GRANT notifications_app TO notifications_servicio;

ALTER DATABASE db_notifications OWNER TO notifications_propietario;
REVOKE ALL ON DATABASE db_notifications FROM PUBLIC;
GRANT CONNECT ON DATABASE db_notifications TO notifications_servicio;

CREATE SCHEMA IF NOT EXISTS notifications AUTHORIZATION notifications_propietario;
ALTER SCHEMA notifications OWNER TO notifications_propietario;
REVOKE ALL ON SCHEMA notifications FROM PUBLIC;
GRANT USAGE ON SCHEMA notifications TO notifications_app, notifications_read_only;

ALTER DEFAULT PRIVILEGES FOR ROLE notifications_propietario IN SCHEMA notifications
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO notifications_app;
ALTER DEFAULT PRIVILEGES FOR ROLE notifications_propietario IN SCHEMA notifications
    GRANT USAGE, SELECT ON SEQUENCES TO notifications_app;
ALTER DEFAULT PRIVILEGES FOR ROLE notifications_propietario IN SCHEMA notifications
    GRANT SELECT ON TABLES TO notifications_read_only;

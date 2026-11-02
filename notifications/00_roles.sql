-- =============================================================================
-- Servicio: notifications
-- Archivo: 00_roles.sql
-- Descripción: Creación del esquema, roles de aplicación y permisos iniciales.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'notifications_migrator') THEN
        CREATE ROLE notifications_migrator WITH LOGIN PASSWORD 'notifications_migrator_pass';
    END IF;

    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'notifications_app') THEN
        CREATE ROLE notifications_app WITH LOGIN PASSWORD 'notifications_app_pass';
    END IF;

    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'notifications_read_only') THEN
        CREATE ROLE notifications_read_only WITH LOGIN PASSWORD 'notifications_ro_pass';
    END IF;
END
$$;

-- Creación del esquema del microservicio
CREATE SCHEMA IF NOT EXISTS notifications AUTHORIZATION notifications_migrator;

-- Asignación de privilegios sobre el esquema
GRANT ALL PRIVILEGES ON SCHEMA notifications TO notifications_migrator;
GRANT USAGE ON SCHEMA notifications TO notifications_app;
GRANT USAGE ON SCHEMA notifications TO notifications_read_only;

-- Configuración de privilegios por defecto para futuras tablas y secuencias
ALTER DEFAULT PRIVILEGES IN SCHEMA notifications 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO notifications_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA notifications 
    GRANT USAGE, SELECT ON SEQUENCES TO notifications_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA notifications 
    GRANT SELECT ON TABLES TO notifications_read_only;
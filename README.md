# RedVital databases

Esquemas SQL separados del código de cada servicio y versionados con Flyway.
Cada servicio persistente tiene una instancia PostgreSQL independiente:

| Servicio | Base | Estado del esquema |
|---|---|---|
| Identidad | `db_identidad` | Migraciones versionadas V001–V004 |
| Campañas | `db_campana` | Migraciones versionadas V001–V003 |
| Donación | `db_donacion` | Migraciones versionadas V001–V007 |
| Institucional | `db_institucional` | Migraciones versionadas V001–V003: territorio (con la geografía DIVIPOLA real), institucion y su serie de auditoría |
| Notificaciones | — | No requiere base de negocio |

Las cuatro bases tienen volúmenes y redes aislados con nombres estables
(`redvital_identidad_data`, `redvital_campana_data`,
`redvital_donacion_data`, `redvital_institucional_data`); el nombre de cada
red se puede sobrescribir con `DB_*_NETWORK`. No se reutilizan las credenciales
de superusuario entre servicios.

Las redes son internas y no publican puertos PostgreSQL en el host. Cada
servicio debe conectarse solo a su red de datos correspondiente y usar el
nombre del servicio PostgreSQL como host (`db-identidad` o `db-campana`) en el
puerto 5432. No conectes Gateway ni otros servicios a esas redes de datos.

## Roles

Las cuatro bases usan roles distintos:

| Rol | Uso | Privilegios |
|---|---|---|
| `postgres` | Inicialización local | Crea roles de la base |
| `*_propietario` | Migraciones Flyway | Administra el esquema |
| `*_servicio` | Ejecución del servicio | Solo los permisos explícitos de sus tablas |

Las tablas de auditoría permiten insertar al servicio, pero no actualizar,
eliminar ni vaciar registros. Los disparadores bloquean esas operaciones
directas también para el rol propietario; este es un control ante errores
operativos, no una garantía contra un administrador que pueda cambiar el
esquema o deshabilitar los disparadores. Una protección contra manipulación por
administradores requiere exportación a un destino externo e independiente.

## Levantar en local

PowerShell:

```powershell
# Ejecuta desde la raiz de este repositorio.
$secretDir = Join-Path (Get-Location).Path "secretos"
New-Item -ItemType Directory -Force -Path $secretDir | Out-Null
$nombres = @(
  "postgres_superusuario_identidad", "identidad_propietario", "identidad_servicio",
  "postgres_superusuario_campana", "campana_propietario", "campana_servicio",
  "postgres_superusuario_donacion", "donacion_propietario", "donacion_servicio",
  "postgres_superusuario_institucional", "institucional_propietario", "institucional_servicio"
)
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
foreach ($nombre in $nombres) {
  $bytes = New-Object byte[] 32
  $rng.GetBytes($bytes)
  $secreto = [BitConverter]::ToString($bytes).Replace("-", "").ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path $secretDir $nombre), $secreto)
}
docker compose -f docker-compose.migraciones.yml up -d
docker compose -f docker-compose.migraciones.yml logs migracion-identidad migracion-campana migracion-donacion migracion-institucional
```

Los archivos de `secretos/` están excluidos del control de versiones. En un
volumen ya inicializado, cambiar esos archivos no rota automáticamente las
contraseñas almacenadas por PostgreSQL.

El script `pruebas/verificar-fase1.sh` se ejecuta dentro de un contenedor
conectado a una sola red de datos; no se conecta desde el host ni comparte una
red de base entre servicios. El CI crea un cliente efímero por red y ejecuta
los alcances `identidad`, `campana`, `donacion` e `institucional`, pasando las
credenciales locales desde archivos ignorados por Git.

## Reglas de cambio

1. No edites una migración que ya haya sido aplicada: Flyway valida su suma de
   comprobación.
2. Añade una nueva migración `V00N__descripcion.sql` en un Pull Request.
3. El responsable del servicio mantiene su modelo de persistencia y verifica
   que mapee el esquema publicado aquí.
4. No agregues tablas ni roles a Institucional hasta recibir su definición
   aprobada.

## Donación

`donacion/` sigue el diccionario de datos del DD V3.0 (secciones 5 y 10):

| Migración | Contenido |
|---|---|
| V001 | Catálogos cerrados: tipo de donación, componentes y vida útil, grupos, compatibilidad (90 filas por regla, Tabla 11), 9 estados y 13 transiciones (Tabla 20), observaciones operativas y reconocimientos |
| V002 | Donante (documento solo como HMAC), consentimientos de solo anexado, intención anónima sin datos de identificación |
| V003 | Donación, unidad, historial de la unidad y reconocimientos otorgados (solo anexado) |
| V004 | Serie de auditoría del contexto de donación |
| V005 | Idempotencia, bandeja de salida y eventos procesados (ADR-018) |
| V006 | Proyección local de campañas publicadas, alimentada por Kafka |
| V007 | Umbrales y alertas de inventario |

`donacion_servicio` solo actualiza las columnas que el dominio cambia (por
ejemplo, en `unidad`: estado, veredicto, custodia y marca de actualización);
la fecha de vencimiento, la donación y todo historial son inmutables para él.

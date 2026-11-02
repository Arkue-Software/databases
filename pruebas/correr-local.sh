#!/usr/bin/env bash
# RedVital · databases · Corre en tu máquina lo mismo que el CI (ci-databases.yml):
#   1. credenciales temporales en secretos/ (no se versionan y se borran al final);
#   2. las cuatro bases aisladas;
#   3. migraciones de Identidad, Campañas, Donación e Institucional con su usuario propietario;
#   4. verificar-fase1.sh contra cada base (esquemas, aislamiento y permisos).
# Al terminar, bien o mal, borra las bases, sus volúmenes y las credenciales.
#
#   bash pruebas/correr-local.sh        (desde la raíz del repo databases)
set -euo pipefail

cd "$(dirname "$0")/.."
RAIZ=$PWD
PROYECTO=redvital-prueba-bds
compose() { docker compose -p "$PROYECTO" -f docker-compose.migraciones.yml "$@"; }

if [ -e secretos ]; then
  echo "Ya existe secretos/ en este repo: no lo toco. Muévelo y vuelve a correr." >&2
  exit 2
fi

limpiar() {
  compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$RAIZ/secretos"
}
trap limpiar EXIT

echo "1/4 Credenciales temporales"
umask 077
mkdir -p secretos
for nombre in \
  postgres_superusuario_identidad identidad_propietario identidad_servicio \
  postgres_superusuario_campana campana_propietario campana_servicio \
  postgres_superusuario_donacion donacion_propietario donacion_servicio \
  postgres_superusuario_institucional institucional_propietario institucional_servicio
do
  openssl rand -hex 32 > "secretos/$nombre"
done
chmod 755 secretos && chmod 644 secretos/*
{
  printf 'PASS_IDENT_PROP=%s\n' "$(cat secretos/identidad_propietario)"
  printf 'PASS_IDENT_SERV=%s\n' "$(cat secretos/identidad_servicio)"
  printf 'PASS_CAMP_PROP=%s\n' "$(cat secretos/campana_propietario)"
  printf 'PASS_CAMP_SERV=%s\n' "$(cat secretos/campana_servicio)"
  printf 'PASS_DON_PROP=%s\n' "$(cat secretos/donacion_propietario)"
  printf 'PASS_DON_SERV=%s\n' "$(cat secretos/donacion_servicio)"
  printf 'PASS_DONACION_ADMIN=%s\n' "$(cat secretos/postgres_superusuario_donacion)"
  printf 'PASS_INST_PROP=%s\n' "$(cat secretos/institucional_propietario)"
  printf 'PASS_INST_SERV=%s\n' "$(cat secretos/institucional_servicio)"
} > secretos/verificador.env

echo "2/4 Bases aisladas"
compose up -d --wait db-identidad db-campana db-donacion db-institucional >/dev/null

echo "3/4 Migraciones"
for base in identidad campana donacion institucional; do
  compose run --rm --no-deps "migracion-$base" 2>&1 | grep -E "Successfully applied|is up to date|ERROR" || true
done

echo "4/4 Verificación de esquemas, aislamiento y permisos"
fallos=0
verificar() {
  local alcance=$1 red=$2 host=$3 prefijo=$4
  echo "  -- $alcance"
  docker run --rm --network "$red" \
    --mount "type=bind,source=$RAIZ/pruebas,target=/pruebas,readonly" \
    --env-file "$RAIZ/secretos/verificador.env" \
    -e "DB_SCOPE=$alcance" -e "${prefijo}_HOST=$host" -e "${prefijo}_PORT=5432" \
    postgres:16 bash /pruebas/verificar-fase1.sh || fallos=$((fallos + 1))
}
verificar identidad redvital_identidad_data db-identidad DB_IDENTIDAD
verificar campana redvital_campana_data db-campana DB_CAMPANA
verificar donacion redvital_donacion_data db-donacion DB_DONACION
verificar institucional redvital_institucional_data db-institucional DB_INSTITUCIONAL

if [ "$fallos" -eq 0 ]; then echo "BASES: OK"; else echo "BASES: $fallos alcance(s) con fallas"; fi
exit "$fallos"

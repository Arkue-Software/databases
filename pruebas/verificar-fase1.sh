#!/usr/bin/env bash
# RedVital · databases · Verificación de T-304.1, T-312.1, T-330.4 (y T-312.5) y db_institucional
# Corre en un contenedor unido a la red de la base indicada por DB_SCOPE.
# Usa DB_*_HOST, DB_*_PORT y las contraseñas PASS_* descritas en README.md.
set -u
fallos=0
SQL_ERROR=
SCOPE=${DB_SCOPE:-}

case "$SCOPE" in
  identidad|campana|donacion|notifications|institucional) ;;
  *) echo "Alcance desconocido: $SCOPE" >&2; exit 2 ;;
esac

puerto_de() {
  case "$1" in
    db_identidad) echo "${DB_IDENTIDAD_PORT:-5432}" ;;
    db_campana) echo "${DB_CAMPANA_PORT:-5432}" ;;
    db_donacion) echo "${DB_DONACION_PORT:-5432}" ;;
    db_notifications) echo "${DB_NOTIFICATIONS_PORT:-5432}" ;;
    db_institucional) echo "${DB_INSTITUCIONAL_PORT:-5432}" ;;
    *) echo "Base desconocida: $1" >&2; return 2 ;;
  esac
}
host_de() {
  case "$1" in
    db_identidad) echo "${DB_IDENTIDAD_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_campana) echo "${DB_CAMPANA_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_donacion) echo "${DB_DONACION_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_notifications) echo "${DB_NOTIFICATIONS_HOST:-${PGHOST:-127.0.0.1}}" ;;
    db_institucional) echo "${DB_INSTITUCIONAL_HOST:-${PGHOST:-127.0.0.1}}" ;;
    *) echo "Base desconocida: $1" >&2; return 2 ;;
  esac
}
scope_includes() { [ "$SCOPE" = "$1" ]; }
sql() { # usuario base clave consulta
  local salida
  if salida=$(PGHOST="$(host_de "$2")" PGPORT="$(puerto_de "$2")" PGPASSWORD="$3" \
    psql -X -q -At -v ON_ERROR_STOP=1 -U "$1" -d "$2" -c "$4" 2>&1); then
    SQL_ERROR=
    return 0
  fi
  SQL_ERROR=$salida
  return 1
}
debe_funcionar() {
  if sql "$2" "$3" "$4" "$5"; then
    echo "  OK    $1"
  else
    echo "  FALLA $1 (debía funcionar)"
    [ -z "$SQL_ERROR" ] || printf '        %s\n' "$SQL_ERROR"
    fallos=$((fallos+1))
  fi
}
debe_fallar()    { if sql "$2" "$3" "$4" "$5"; then echo "  FALLA $1 (debía ser rechazado)"; fallos=$((fallos+1)); else echo "  OK    $1"; fi; }
valor()          { PGHOST="$(host_de "$2")" PGPORT="$(puerto_de "$2")" PGPASSWORD="$3" \
  psql -X -q -At -U "$1" -d "$2" -c "$4" 2>/dev/null; }

IP=identidad_propietario; IS=identidad_servicio; CP=campana_propietario; CS=campana_servicio
pIP="${PASS_IDENT_PROP:-}"; pIS="${PASS_IDENT_SERV:-}"; pCP="${PASS_CAMP_PROP:-}"; pCS="${PASS_CAMP_SERV:-}"
DP=donacion_propietario; DS=donacion_servicio
pDP="${PASS_DON_PROP:-}"; pDS="${PASS_DON_SERV:-}"
pD="${PASS_DONACION_ADMIN:-}"
NP=institucional_propietario; NS=institucional_servicio
pNP="${PASS_INST_PROP:-}"; pNS="${PASS_INST_SERV:-}"
U=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)

if scope_includes identidad; then
  echo "T-304.1 — db_identidad: esquema y roles"
  [ "$(valor $IS db_identidad "$pIS" "SELECT count(*) FROM rol")" = "6" ] && echo "  OK    catálogo de roles con exactamente 6 valores" || { echo "  FALLA catálogo de roles"; fallos=$((fallos+1)); }
  debe_funcionar "servicio inserta un usuario"      $IS db_identidad "$pIS" "INSERT INTO usuario (id, correo, credencial_hash, rol_id) VALUES ('$U','verif-$U@banco-ficticio.test','x','operador')"
  debe_funcionar "servicio actualiza un usuario"    $IS db_identidad "$pIS" "UPDATE usuario SET activo=false WHERE id='$U'"
  debe_fallar    "servicio NO borra usuarios"       $IS db_identidad "$pIS" "DELETE FROM usuario WHERE id='$U'"
  debe_fallar    "servicio NO crea tablas"          $IS db_identidad "$pIS" "CREATE TABLE intrusa (x int)"
  debe_fallar    "servicio NO modifica el catálogo de roles" $IS db_identidad "$pIS" "INSERT INTO rol VALUES ('extra','x','x')"
  debe_fallar    "sesión de más de 8 horas"         $IS db_identidad "$pIS" "INSERT INTO sesion (usuario_id, secreto_hash, emitida_en, expira_en) VALUES ('$U','x', now(), now() + interval '9 hours')"
  debe_fallar    "jurisdicción institucional sin institución" $IS db_identidad "$pIS" "INSERT INTO usuario_jurisdiccion (usuario_id, ambito, asignada_por) VALUES ('$U','institucion','$U')"
  debe_fallar    "cliente de servicio no reconocido" $IS db_identidad "$pIS" "INSERT INTO credencial_servicio (cliente, secreto_hash) VALUES ('institucional','x')"

  echo "T-330.4 — serie de auditoría de Identidad (solo anexado)"
  debe_funcionar "servicio registra una denegación anónima" $IS db_identidad "$pIS" "INSERT INTO registro_auditoria_ident (actor_tipo, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('anonimo','campanias:GET','campania','denegado','$U')"
  debe_fallar    "correlación de más de 36 caracteres (tamaño de un UUID)" $IS db_identidad "$pIS" "INSERT INTO registro_auditoria_ident (actor_tipo, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('anonimo','x','x','denegado', repeat('a', 37))"
  debe_fallar    "anónimo con actor_id es rechazado" $IS db_identidad "$pIS" "INSERT INTO registro_auditoria_ident (actor_tipo, actor_id, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('anonimo','alguien','x','x','denegado','x')"
  debe_fallar    "servicio NO actualiza la auditoría"  $IS db_identidad "$pIS" "UPDATE registro_auditoria_ident SET resultado='permitido' WHERE correlacion_id='$U'"
  debe_fallar    "servicio NO borra la auditoría"      $IS db_identidad "$pIS" "DELETE FROM registro_auditoria_ident WHERE correlacion_id='$U'"
  debe_fallar    "servicio NO vacía la auditoría"      $IS db_identidad "$pIS" "TRUNCATE registro_auditoria_ident"
  debe_fallar    "trigger bloquea UPDATE directo del PROPIETARIO" $IP db_identidad "$pIP" "UPDATE registro_auditoria_ident SET resultado='permitido' WHERE correlacion_id='$U'"
  debe_fallar    "trigger bloquea TRUNCATE directo del PROPIETARIO" $IP db_identidad "$pIP" "TRUNCATE registro_auditoria_ident"

  debe_fallar "campana_servicio no existe en db_identidad" $CS db_identidad "$pCS" "SELECT 1"
fi

if scope_includes campana; then
  echo "T-312.1 — db_campana: esquema y roles"
  C=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
  debe_funcionar "servicio crea una campaña"  $CS db_campana "$pCS" "INSERT INTO campania (id, institucion_id, territorio_codigo, territorio_ruta, nombre, sede, inicia_en, termina_en, cupo_total, creada_por) VALUES ('$C','$U','11001','/00/11/11001','Campaña ficticia','Sede ficticia', now()+interval '1 day', now()+interval '2 days', 10, '$U')"
  debe_fallar    "cupo reservado mayor que el total" $CS db_campana "$pCS" "UPDATE campania SET cupo_reservado = 11 WHERE id='$C'"
  debe_fallar    "campaña que termina antes de empezar" $CS db_campana "$pCS" "UPDATE campania SET termina_en = inicia_en - interval '1 hour' WHERE id='$C'"
  debe_fallar    "publicada sin fecha de publicación" $CS db_campana "$pCS" "UPDATE campania SET estado='publicada' WHERE id='$C'"
  debe_funcionar "reserva de cupo"            $CS db_campana "$pCS" "INSERT INTO reserva_cupo (campania_id, usuario_id, expira_en) VALUES ('$C','$U', now()+interval '23 hours')"
  debe_fallar    "reserva de más de 24 horas" $CS db_campana "$pCS" "INSERT INTO reserva_cupo (campania_id, usuario_id, expira_en) VALUES ('$C','$U', now()+interval '25 hours')"
  debe_fallar    "servicio NO borra campañas" $CS db_campana "$pCS" "DELETE FROM campania WHERE id='$C'"
  debe_fallar    "servicio NO crea tablas"    $CS db_campana "$pCS" "CREATE TABLE intrusa (x int)"
  debe_fallar    "servicio de Campañas NO entra a db_identidad" $CS db_identidad "$pCS" "SELECT 1"

  echo "T-312.5 — serie de auditoría de Campañas (solo anexado)"
  debe_funcionar "servicio registra un hecho" $CS db_campana "$pCS" "INSERT INTO registro_auditoria_camp (actor_tipo, actor_id, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('usuario','$U','publicar_campania','campania','permitido','$C')"
  debe_fallar    "servicio NO borra la auditoría"         $CS db_campana "$pCS" "DELETE FROM registro_auditoria_camp"
  debe_fallar    "trigger bloquea UPDATE directo del PROPIETARIO" $CP db_campana "$pCP" "UPDATE registro_auditoria_camp SET resultado='denegado'"
  debe_fallar    "trigger bloquea TRUNCATE directo del PROPIETARIO" $CP db_campana "$pCP" "TRUNCATE registro_auditoria_camp"

  debe_fallar "identidad_servicio no existe en db_campana" $IS db_campana "$pIS" "SELECT 1"
fi

if scope_includes donacion; then
  echo "DB-DON — db_donacion: catálogos cerrados (DD V3.0, Tablas 10, 11 y 20)"
  [ "$(valor $DS db_donacion "$pDS" "SELECT count(*) FROM estado_unidad")" = "9" ] && echo "  OK    nueve estados de unidad" || { echo "  FALLA estados de unidad"; fallos=$((fallos+1)); }
  [ "$(valor $DS db_donacion "$pDS" "SELECT count(*) FROM transicion_valida")" = "13" ] && echo "  OK    trece transiciones válidas" || { echo "  FALLA transiciones válidas"; fallos=$((fallos+1)); }
  [ "$(valor $DS db_donacion "$pDS" "SELECT count(*) FROM compatibilidad")" = "90" ] && echo "  OK    noventa combinaciones de compatibilidad" || { echo "  FALLA compatibilidad"; fallos=$((fallos+1)); }
  [ "$(valor $DS db_donacion "$pDS" "SELECT count(*) FROM estado_unidad WHERE cuenta_disponible")" = "1" ] && echo "  OK    un solo estado cuenta como existencia (EC-12)" || { echo "  FALLA cuenta_disponible"; fallos=$((fallos+1)); }

  echo "DB-DON — db_donacion: roles y permisos por columna"
  D=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
  N=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
  debe_funcionar "servicio registra una donación anónima" $DS db_donacion "$pDS" "INSERT INTO donacion (id, tipo_donacion_id, institucion_id, fecha_captacion, operador_id) VALUES ('$D', (SELECT id FROM tipo_donacion WHERE codigo='sangre_total'), '$U', now(), '$U')"
  debe_funcionar "servicio crea una unidad captada" $DS db_donacion "$pDS" "INSERT INTO unidad (id, donacion_id, componente_id, grupo_sanguineo_id, institucion_custodia_id, estado_id, fecha_vencimiento) VALUES ('$N','$D',(SELECT id FROM componente WHERE codigo='plasma'),(SELECT id FROM grupo_sanguineo WHERE codigo='O+'),'$U',(SELECT id FROM estado_unidad WHERE codigo='captada'), current_date + 365)"
  debe_funcionar "servicio cambia el estado de la unidad" $DS db_donacion "$pDS" "UPDATE unidad SET estado_id=(SELECT id FROM estado_unidad WHERE codigo='fraccionada'), actualizado_en=now() WHERE id='$N'"
  debe_fallar    "servicio NO cambia el vencimiento" $DS db_donacion "$pDS" "UPDATE unidad SET fecha_vencimiento = current_date WHERE id='$N'"
  debe_fallar    "servicio NO reescribe una donación" $DS db_donacion "$pDS" "UPDATE donacion SET campania_id=NULL WHERE id='$D'"
  debe_fallar    "servicio NO borra unidades" $DS db_donacion "$pDS" "DELETE FROM unidad WHERE id='$N'"
  debe_fallar    "servicio NO modifica la matriz de transiciones" $DS db_donacion "$pDS" "DELETE FROM transicion_valida"
  debe_fallar    "servicio NO crea tablas" $DS db_donacion "$pDS" "CREATE TABLE intrusa (x int)"
  debe_fallar    "donación con donante e intención a la vez (IN-07)" $DS db_donacion "$pDS" "INSERT INTO donacion (id, donante_id, intencion_id, tipo_donacion_id, institucion_id, fecha_captacion, operador_id) VALUES (gen_random_uuid(), '$U', '$U', (SELECT id FROM tipo_donacion), '$U', now(), '$U')"
  debe_fallar    "intención con código ambiguo (EC-17)" $DS db_donacion "$pDS" "INSERT INTO intencion_donacion (id, codigo, expira_en) VALUES (gen_random_uuid(), 'O0O0O0O0O0O0', now() + interval '1 day')"
  debe_fallar    "intención de más de 30 días (D-08)" $DS db_donacion "$pDS" "INSERT INTO intencion_donacion (id, codigo, expira_en) VALUES (gen_random_uuid(), '23456789ABCD', now() + interval '31 days')"

  echo "DB-DON — historial, bitácora y bandeja de solo anexado"
  debe_funcionar "servicio registra el evento de la unidad" $DS db_donacion "$pDS" "INSERT INTO evento_unidad (id, unidad_id, estado_nuevo_id, actor_tipo, actor_id, institucion_id, correlacion_id) VALUES (gen_random_uuid(), '$N', (SELECT id FROM estado_unidad WHERE codigo='captada'), 'usuario', '$U', '$U', '$U')"
  debe_fallar    "servicio NO borra el historial de la unidad" $DS db_donacion "$pDS" "DELETE FROM evento_unidad WHERE unidad_id='$N'"
  debe_fallar    "trigger bloquea UPDATE del historial por el PROPIETARIO" $DP db_donacion "$pDP" "UPDATE evento_unidad SET actor_id='otro' WHERE unidad_id='$N'"
  debe_funcionar "servicio registra un hecho en la bitácora" $DS db_donacion "$pDS" "INSERT INTO registro_auditoria (id, actor_tipo, actor_id, operacion, recurso_tipo, resultado, correlacion_id) VALUES (gen_random_uuid(), 'usuario', '$U', 'registrar_donacion', 'donacion', 'permitido', '$U')"
  debe_fallar    "servicio NO borra la bitácora" $DS db_donacion "$pDS" "DELETE FROM registro_auditoria"
  debe_fallar    "trigger bloquea TRUNCATE de la bitácora por el PROPIETARIO" $DP db_donacion "$pDP" "TRUNCATE registro_auditoria"
  debe_funcionar "servicio escribe en la bandeja de salida" $DS db_donacion "$pDS" "INSERT INTO evento_salida (id, tipo, version_esquema, tema, clave, carga, correlacion_id) VALUES (gen_random_uuid(), 'donation.completed', 1, 'redvital.donacion.donation-completed.v1', '$D', '{}'::jsonb, '$U')"
  debe_fallar    "la bandeja solo admite eventos activos del catálogo" $DS db_donacion "$pDS" "INSERT INTO evento_salida (id, tipo, version_esquema, tema, clave, carga, correlacion_id) VALUES (gen_random_uuid(), 'transfusion.completed', 1, 'x', 'x', '{}'::jsonb, '$U')"

  debe_fallar "campana_servicio no existe en db_donacion" $CS db_donacion "$pCS" "SELECT 1"
fi

if scope_includes institucional; then
  echo "DB-INST — db_institucional: jerarquía territorial (RF-09, IN-13)"
  [ "$(valor $NS db_institucional "$pNS" "SELECT count(*) FROM territorio WHERE nivel='nacional'")" = "1" ] && echo "  OK    una sola raíz nacional" || { echo "  FALLA raíz nacional"; fallos=$((fallos+1)); }
  [ "$(valor $NS db_institucional "$pNS" "SELECT count(*) FROM territorio WHERE nivel='departamental'")" = "33" ] && echo "  OK    treinta y tres departamentos" || { echo "  FALLA departamentos"; fallos=$((fallos+1)); }
  [ "$(valor $NS db_institucional "$pNS" "SELECT ruta FROM territorio WHERE codigo_divipola='05001'")" = "/00/05/05001" ] && echo "  OK    la ruta se deriva del código" || { echo "  FALLA ruta de Medellín"; fallos=$((fallos+1)); }
  debe_fallar    "ruta que no corresponde al código (IN-13)" $NS db_institucional "$pNS" "INSERT INTO territorio (codigo_divipola, nombre, nivel, padre_id, ruta) VALUES ('05999','Ficticio','municipal',(SELECT id FROM territorio WHERE codigo_divipola='05'),'/00/05/05998')"
  debe_fallar    "segunda raíz nacional" $NS db_institucional "$pNS" "INSERT INTO territorio (codigo_divipola, nombre, nivel, ruta) VALUES ('00','Otra','nacional','/00')"
  debe_fallar    "municipio colgado de otro departamento" $NS db_institucional "$pNS" "INSERT INTO territorio (codigo_divipola, nombre, nivel, padre_id, ruta) VALUES ('05998','Ficticio','municipal',(SELECT id FROM territorio WHERE codigo_divipola='11'),'/00/05/05998')"
  debe_funcionar "servicio da de alta un municipio" $NS db_institucional "$pNS" "INSERT INTO territorio (codigo_divipola, nombre, nivel, padre_id, ruta) VALUES ('05997','Municipio de verificación','municipal',(SELECT id FROM territorio WHERE codigo_divipola='05'),'/00/05/05997')"
  debe_fallar    "servicio NO cambia la ruta de un territorio" $NS db_institucional "$pNS" "UPDATE territorio SET ruta='/00/05/05996' WHERE codigo_divipola='05997'"
  debe_fallar    "servicio NO borra territorios" $NS db_institucional "$pNS" "DELETE FROM territorio WHERE codigo_divipola='05997'"

  echo "DB-INST — db_institucional: instituciones (EC-39, EC-42)"
  debe_funcionar "servicio da de alta una institución" $NS db_institucional "$pNS" "INSERT INTO institucion (id, codigo, nombre, tipo, territorio_id, creado_por) VALUES ('$U','VER-$RANDOM','Banco de verificación (ficticio)','banco_de_sangre',(SELECT id FROM territorio WHERE codigo_divipola='05997'),'$U')"
  debe_fallar    "institución adscrita a un departamento" $NS db_institucional "$pNS" "INSERT INTO institucion (codigo, nombre, tipo, territorio_id, creado_por) VALUES ('VER-DEP','Ficticia','banco_de_sangre',(SELECT id FROM territorio WHERE codigo_divipola='05'),'$U')"
  debe_funcionar "servicio da de baja la institución" $NS db_institucional "$pNS" "UPDATE institucion SET vigente=false WHERE id='$U'"
  debe_fallar    "servicio NO cambia el tipo" $NS db_institucional "$pNS" "UPDATE institucion SET tipo='servicio_transfusion' WHERE id='$U'"
  debe_fallar    "servicio NO cambia la fecha de alta" $NS db_institucional "$pNS" "UPDATE institucion SET creado_en=now() - interval '1 year' WHERE id='$U'"
  debe_fallar    "servicio NO borra instituciones" $NS db_institucional "$pNS" "DELETE FROM institucion WHERE id='$U'"
  debe_fallar    "servicio NO crea tablas" $NS db_institucional "$pNS" "CREATE TABLE intrusa (x int)"

  echo "DB-INST — serie de auditoría institucional (solo anexado)"
  debe_funcionar "servicio registra un hecho" $NS db_institucional "$pNS" "INSERT INTO registro_auditoria_inst (actor_tipo, actor_id, operacion, recurso_tipo, resultado, correlacion_id) VALUES ('usuario','$U','crear_institucion','institucion','permitido','$U')"
  debe_fallar    "servicio NO borra la auditoría" $NS db_institucional "$pNS" "DELETE FROM registro_auditoria_inst"
  debe_fallar    "trigger bloquea UPDATE directo del PROPIETARIO" $NP db_institucional "$pNP" "UPDATE registro_auditoria_inst SET resultado='denegado'"
  debe_fallar    "trigger bloquea TRUNCATE directo del PROPIETARIO" $NP db_institucional "$pNP" "TRUNCATE registro_auditoria_inst"

  debe_fallar "campana_servicio no existe en db_institucional" $CS db_institucional "$pCS" "SELECT 1"
fi

if scope_includes notifications; then
  echo "T-DB — db_notifications: conexión y permisos del servicio"
  debe_funcionar "notifications_servicio conecta y consulta el esquema" notifications_servicio db_notifications "$pNS" "SELECT count(*) FROM notifications.plantillas"
  debe_funcionar "notifications_servicio inserta una plantilla" notifications_servicio db_notifications "$pNS" "INSERT INTO notifications.plantillas (codigo, nombre, canal, cuerpo_patron) VALUES ('verif-$U', 'Verificación', 'CORREO', 'verificación')"
  debe_funcionar "notifications_servicio elimina la plantilla de prueba" notifications_servicio db_notifications "$pNS" "DELETE FROM notifications.plantillas WHERE codigo = 'verif-$U'"
fi

echo; [ $fallos -eq 0 ] && echo "Fase 1: todas las verificaciones pasaron" || echo "Fase 1: $fallos verificación(es) fallaron"
exit $fallos

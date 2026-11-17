#!/usr/bin/env bash
# Funciones de guardar-bd.sh, restaurar-bd.sh y reiniciar-bd.sh para la copia de la BD del usuario. No se ejecuta por sí solo.
# Solo MySQL y MariaDB. Las copias van en .magents/bd-usuario/, que no se versiona.
# El archivo «pendiente» indica que la BD se ha restablecido y que esa copia está sin restaurar.

bd_carpeta="$magents_carpeta/bd-usuario"
bd_pendiente="$bd_carpeta/pendiente"
bd_copias_maximas=5

bd_compose() {
  docker compose -f "$magents_compose" "$@"
}

bd_hay_servicio() {
  bd_compose config --services 2>/dev/null | grep -qx bd
}

# Nombre de la copia sin restaurar, o nada.
bd_copia_pendiente() {
  [ -f "$bd_pendiente" ] || return 0
  head -1 "$bd_pendiente"
}

bd_arrancar() {
  if [ -n "$(bd_compose ps --status running -q bd 2>/dev/null)" ]; then
    return 0
  fi
  bd_compose up -d --wait --wait-timeout 900 bd >&2
}

# Ejecuta en el servicio bd, con su usuario de pruebas. Deja $cliente, $volcado, $u y $d.
bd_ejecutar() {
  bd_compose exec -T bd sh -c '
    u="${MARIADB_USER:-${MYSQL_USER:-}}"
    d="${MARIADB_DATABASE:-${MYSQL_DATABASE:-}}"
    export MYSQL_PWD="${MARIADB_PASSWORD:-${MYSQL_PASSWORD:-}}"
    cliente="$(command -v mariadb || command -v mysql)"
    volcado="$(command -v mariadb-dump || command -v mysqldump)"
    if [ -z "$u" ] || [ -z "$d" ] || [ -z "$cliente" ] || [ -z "$volcado" ]; then
      echo "el servicio bd no es MySQL o MariaDB con usuario y base de datos de pruebas" >&2
      exit 90
    fi
    '"$1"
}

# Falla solo si el servicio bd es de otro motor: de ese no se sabe hacer copias.
bd_admitida() {
  local codigo=0
  bd_ejecutar 'true' 2>/dev/null || codigo=$?
  [ "$codigo" -ne 90 ]
}

# Uso: bd_volcar <archivo>. Vuelca esquema y datos; el archivo solo queda si el volcado termina bien.
bd_volcar() {
  local archivo="$1" temporal="$1.parcial"
  # utf8mb4, porque el juego por defecto de las versiones antiguas pierde los caracteres de cuatro bytes.
  # --no-tablespaces evita pedir un permiso que el usuario de pruebas no tiene; las versiones antiguas no lo conocen.
  if ! bd_ejecutar '
      opciones="--single-transaction --triggers --hex-blob --default-character-set=utf8mb4"
      if "$volcado" --help 2>/dev/null | grep -q -- "--no-tablespaces"; then
        opciones="$opciones --no-tablespaces"
      fi
      "$volcado" -u"$u" $opciones "$d"' > "$temporal"; then
    rm -f "$temporal"
    return 1
  fi
  if ! tail -5 "$temporal" | grep -q 'Dump completed'; then
    rm -f "$temporal"
    return 1
  fi
  mv "$temporal" "$archivo"
}

# Uso: bd_guardar [etiqueta]. Escribe en la salida el nombre de la copia.
bd_guardar() {
  local etiqueta="${1:-}" nombre
  nombre="$(date +%Y%m%d-%H%M%S)${etiqueta:+-$etiqueta}.sql"
  (umask 077 && mkdir -p "$bd_carpeta")
  if ! (umask 077 && bd_volcar "$bd_carpeta/$nombre"); then
    return 1
  fi
  bd_podar
  echo "$nombre"
}

# Conserva las copias más recientes y, siempre, la que está sin restaurar.
bd_podar() {
  local pendiente copia n=0
  pendiente="$(bd_copia_pendiente)"
  while IFS= read -r copia; do
    n=$((n + 1))
    if [ "$n" -gt "$bd_copias_maximas" ] && [ "$copia" != "$pendiente" ]; then
      rm -f "$bd_carpeta/$copia"
    fi
  done < <(cd "$bd_carpeta" && ls -1 -- *.sql 2>/dev/null | sort -r)
}

# Uso: bd_cargar <archivo>. Borra las tablas y vistas actuales y carga el volcado.
bd_cargar() {
  bd_ejecutar '
    {
      echo "SET FOREIGN_KEY_CHECKS=0;"
      "$cliente" -u"$u" -N -B -e "SELECT CONCAT(\"DROP \", IF(table_type = \"VIEW\", \"VIEW\", \"TABLE\"), \" IF EXISTS \`\", table_name, \"\`;\") FROM information_schema.tables WHERE table_schema = DATABASE()" "$d"
    } | "$cliente" -u"$u" "$d" && "$cliente" -u"$u" --default-character-set=utf8mb4 "$d"' < "$1"
}

# Uso: bd_aplicar <archivo .sql>. Se detiene en el primer error.
bd_aplicar() {
  bd_ejecutar '"$cliente" -u"$u" --default-character-set=utf8mb4 "$d"' < "$1"
}

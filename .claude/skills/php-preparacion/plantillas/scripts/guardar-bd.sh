#!/usr/bin/env bash
# Guarda una copia de la BD de este entorno, con tus datos, en .magents/bd-usuario/. No cambia la BD.
# Uso: guardar-bd.sh [etiqueta]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/confirmar.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bd-comun.sh"
magents_cabecera

etiqueta="${1:-}"
if [[ ! "$etiqueta" =~ ^[A-Za-z0-9._-]*$ ]]; then
  magents_error "ERROR: la etiqueta solo admite letras, números, puntos y guiones."
  exit 1
fi
if ! bd_hay_servicio; then
  magents_error "ERROR: este entorno no tiene servicio bd."
  exit 1
fi
pendiente="$(bd_copia_pendiente)"
if [ -n "$pendiente" ]; then
  magents_error "ERROR: la BD actual es la de pruebas, no la tuya: tus datos están en la copia $pendiente, sin restaurar. Recupérala con restaurar-bd.sh, o descártala con restaurar-bd.sh --descartar."
  exit 4
fi
if ! bd_arrancar; then
  magents_error "ERROR: el servicio bd no arranca; no se ha guardado nada."
  exit 1
fi
if ! bd_admitida; then
  magents_error "ERROR: el servicio bd no es MySQL ni MariaDB; no se ha guardado nada."
  exit 1
fi
if ! nombre="$(bd_guardar "$etiqueta")"; then
  magents_error "ERROR: el volcado ha fallado; no se ha guardado nada."
  exit 1
fi
magents_ok "Copia guardada: .magents/bd-usuario/$nombre"

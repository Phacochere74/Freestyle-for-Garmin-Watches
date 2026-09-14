#!/usr/bin/env bash
#
# Compilation en ligne de commande des deux applications.
#
# Prerequis :
#   - SDK Connect IQ installe (monkeyc dans le PATH, ou variable CIQ_SDK)
#   - une cle developpeur au format DER (voir README)
#
# Usage :
#   tools/build.sh                            # l'app, pour epix2pro47mm
#   tools/build.sh app epix2pro47mm
#   tools/build.sh datafield epix2pro47mm
#   tools/build.sh both epix2pro47mm
#
set -euo pipefail

TARGET="${1:-app}"
DEVICE="${2:-epix2pro47mm}"
KEY="${3:-developer_key.der}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MONKEYC="monkeyc"
if [[ -n "${CIQ_SDK:-}" ]]; then
  MONKEYC="${CIQ_SDK}/bin/monkeyc"
fi

if ! command -v "${MONKEYC}" >/dev/null 2>&1 && [[ ! -x "${MONKEYC}" ]]; then
  echo "monkeyc introuvable. Installe le SDK Connect IQ et/ou exporte CIQ_SDK." >&2
  exit 1
fi

if [[ ! -f "${ROOT}/${KEY}" ]]; then
  echo "Cle developpeur absente : ${ROOT}/${KEY}" >&2
  echo "Genere-la depuis VS Code : Ctrl+Shift+P > Monkey C: Generate a Developer Key" >&2
  exit 1
fi

build() {
  local jungle="$1" name="$2"
  echo "== ${name} -> ${DEVICE}"
  "${MONKEYC}" \
    --jungles "${ROOT}/${jungle}" \
    --device "${DEVICE}" \
    --private-key "${ROOT}/${KEY}" \
    --output "${ROOT}/bin/${name}-${DEVICE}.prg" \
    --warn
  echo "   OK -> bin/${name}-${DEVICE}.prg"
}

mkdir -p "${ROOT}/bin"

case "${TARGET}" in
  app)       build monkey.jungle    freestyle ;;
  datafield) build datafield.jungle freestyle-datafield ;;
  both)      build monkey.jungle    freestyle
             build datafield.jungle freestyle-datafield ;;
  *)
    echo "Cible inconnue : ${TARGET} (attendu : app, datafield ou both)" >&2
    exit 1
    ;;
esac

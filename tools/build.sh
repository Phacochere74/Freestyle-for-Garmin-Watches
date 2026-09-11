#!/usr/bin/env bash
#
# Compilation en ligne de commande.
#
# Prerequis :
#   - SDK Connect IQ installe (monkeyc dans le PATH, ou variable CIQ_SDK)
#   - une cle developpeur au format DER (voir README)
#
# Usage :
#   tools/build.sh                 # compile pour fenix7
#   tools/build.sh venu2 developer_key.der
#
set -euo pipefail

DEVICE="${1:-fenix7}"
KEY="${2:-developer_key.der}"
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
  echo "Genere-la avec :" >&2
  echo "  openssl genrsa -out developer_key.pem 4096" >&2
  echo "  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt" >&2
  exit 1
fi

mkdir -p "${ROOT}/bin"
"${MONKEYC}" \
  --jungles "${ROOT}/monkey.jungle" \
  --device "${DEVICE}" \
  --private-key "${ROOT}/${KEY}" \
  --output "${ROOT}/bin/freestyle-${DEVICE}.prg" \
  --warn

echo "OK -> bin/freestyle-${DEVICE}.prg"

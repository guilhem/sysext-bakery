#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download tailscale binaries and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

tarball="$(curl -fsSL "https://pkgs.tailscale.com/stable/?v=${VERSION}&mode=json" | jq -r .Tarballs.amd64)"

URL="https://pkgs.tailscale.com/stable/${tarball}"

TMP_DIR="$(mktemp -d)"

#trap 'rm -rf "${TMP_DIR}"' EXIT

curl -o "${TMP_DIR}/tailscale-amd64.tar.gz" -fsSL "${URL}"

mkdir -p "${TMP_DIR}/extracted"
tar xf "${TMP_DIR}/tailscale-amd64.tar.gz" -C "${TMP_DIR}/extracted" --strip-components=1

rm -rf "${SYSEXTNAME}"

mkdir -p "${SYSEXTNAME}"/usr/local/{bin,sbin,lib/{systemd/system,extension-release.d}}

mv "${TMP_DIR}/extracted/tailscale" "${SYSEXTNAME}/usr/local/bin/tailscale"
mv "${TMP_DIR}/extracted/tailscaled" "${SYSEXTNAME}/usr/local/sbin/tailscaled"
mv "${TMP_DIR}/extracted/systemd/tailscaled.service" "${SYSEXTNAME}/usr/local/lib/systemd/system/tailscaled.service"

sed -i 's/--port.*//g' "${SYSEXTNAME}/usr/local/lib/systemd/system/tailscaled.service"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"

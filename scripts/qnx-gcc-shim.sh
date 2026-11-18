#!/usr/bin/env bash
# Adapt QNX's qcc variant flag to the SDP's versioned GCC driver.
set -euo pipefail

: "${QNX_HOST:?source the QNX SDP environment first}"
: "${QNX_TARGET:?source the QNX SDP environment first}"

compiler="${QNX_HOST}/usr/bin/aarch64-unknown-nto-qnx7.1.0-gcc-8.3.0"
args=()
for arg in "$@"; do
  case "$arg" in
    -Vgcc_ntoaarch64le|-Vgcc_ntoaarch64le_cxx) ;;
    *) args+=("$arg") ;;
  esac
done

exec "$compiler" --sysroot="${QNX_TARGET}/aarch64le" "${args[@]}"

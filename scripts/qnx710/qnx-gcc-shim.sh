#!/usr/bin/env bash
# Adapt QNX's qcc variant flag to the SDP's versioned GCC driver.
set -euo pipefail

: "${QNX_HOST:?source the QNX SDP environment first}"
: "${QNX_TARGET:?source the QNX SDP environment first}"

compiler="${QNX_HOST}/usr/bin/aarch64-unknown-nto-qnx7.1.0-gcc-8.3.0"
args=()
is_compile=false
for arg in "$@"; do
  case "$arg" in
    -Vgcc_ntoaarch64le|-Vgcc_ntoaarch64le_cxx) ;;
    -c) is_compile=true; args+=("$arg") ;;
    *) args+=("$arg") ;;
  esac
done

if [[ "$is_compile" == true ]]; then
  # Expose QNX's pthread initializers and use compile-time ARM capabilities;
  # AWS-LC has no QNX runtime CPU probe for OPENSSL_cpuid_setup.
  args=(-D_QNX_SOURCE -DOPENSSL_STATIC_ARMCAP "${args[@]}")
fi

exec "$compiler" --sysroot="${QNX_TARGET}/aarch64le" "${args[@]}"

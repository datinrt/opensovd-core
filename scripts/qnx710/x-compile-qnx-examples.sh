#!/usr/bin/env bash
# Cross-compile OpenSOVD examples for QNX SDP 7.1 AArch64.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
if [[ -n "${QNX_ENV_SCRIPT:-}" ]]; then
  qnx_env="${QNX_ENV_SCRIPT}"
elif [[ -f "${HOME}/qnx710/qnxsdp-env.sh" ]]; then
  qnx_env="${HOME}/qnx710/qnxsdp-env.sh"
else
  qnx_env="/opt/qnx710/qnxsdp-env.sh"
fi
target="aarch64-unknown-nto-qnx710"
toolchain="nightly"
target_dir="${CARGO_TARGET_DIR:-${repo_root}/target/qnx-examples}"
compiler_shim="${script_dir}/qnx-gcc-shim.sh"
example=""
all_examples=false
client_example=false
strip_binary=false
clean_build=false

usage() {
  echo "Usage: $0 (-e <server-example> | -a | -client) [-c] [-s]"
  echo "  -e  Example name under examples/server"
  echo "  -a  Compile all examples under examples/server"
  echo "  -client  Compile the client example under examples/client"
  echo "  -c  Clean the QNX target directory before building"
  echo "  -s  Strip compiled example binaries after building"
}

remaining_args=()
for arg in "$@"; do
  if [[ "${arg}" == "-client" ]]; then
    client_example=true
  else
    remaining_args+=("${arg}")
  fi
done
set -- "${remaining_args[@]}"

while getopts ":e:acsh" option; do
  case "${option}" in
    e) example="${OPTARG}" ;;
    a) all_examples=true ;;
    c) clean_build=true ;;
    s) strip_binary=true ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))
if [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi
mode_count=0
if [[ -n "${example}" ]]; then
  mode_count=$((mode_count + 1))
fi
if [[ "${all_examples}" == true ]]; then
  mode_count=$((mode_count + 1))
fi
if [[ "${client_example}" == true ]]; then
  mode_count=$((mode_count + 1))
fi
if [[ "${mode_count}" -ne 1 ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "${qnx_env}" ]]; then
  echo "QNX SDP environment script not found: ${qnx_env}" >&2
  echo "Set QNX_ENV_SCRIPT to the path of qnxsdp-env.sh." >&2
  exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
  echo "rustup is required to install/select the nightly Rust toolchain." >&2
  exit 1
fi

if ! rustup toolchain list | grep -q '^nightly-'; then
  rustup toolchain install "${toolchain}" --component rust-src
elif ! rustup component list --toolchain "${toolchain}" --installed | grep -q '^rust-src'; then
  rustup component add rust-src --toolchain "${toolchain}"
fi

# The QNX target's standard library is built from rust-src by Cargo nightly.
source "${qnx_env}"

if [[ ! -x "${compiler_shim}" ]]; then
  echo "QNX compiler shim is missing or not executable: ${compiler_shim}" >&2
  exit 1
fi

export CARGO_TARGET_DIR="${target_dir}"
export CARGO_TARGET_AARCH64_UNKNOWN_NTO_QNX710_LINKER="${compiler_shim}"
export CC_aarch64_unknown_nto_qnx710="${compiler_shim}"
export CXX_aarch64_unknown_nto_qnx710="${compiler_shim}"

cd "${repo_root}"
if [[ "${clean_build}" == true ]]; then
  rm -rf -- "${CARGO_TARGET_DIR}/${target}"
fi

if [[ "${client_example}" == true ]]; then
  package="opensovd-examples-client"
  examples=(client)
  build_args=(--release --target "${target}" -p "${package}" --example client)
elif [[ "${all_examples}" == true ]]; then
  package="opensovd-examples-server"
  build_args=(--release --target "${target}" -p "${package}")
  build_args+=(--examples --features tls)
  examples=(bulkdata simple systemd auth updates mtls)
else
  package="opensovd-examples-server"
  build_args=(--release --target "${target}" -p "${package}")
  if [[ "${example}" == "mtls" ]]; then
    build_args+=(--features tls)
  fi
  build_args+=(--example "${example}")
  examples=("${example}")
fi

cargo +"${toolchain}" -Z build-std=std,panic_unwind build "${build_args[@]}"

if [[ "${strip_binary}" == true ]]; then
  strip_tool="${QNX_HOST}/usr/bin/aarch64-unknown-nto-qnx7.1.0-strip"
  if [[ ! -x "${strip_tool}" ]]; then
    echo "QNX strip tool not found: ${strip_tool}" >&2
    exit 1
  fi
fi

for built_example in "${examples[@]}"; do
  binary="${CARGO_TARGET_DIR}/${target}/release/examples/${built_example}"
  if [[ "${strip_binary}" == true ]]; then
    "${strip_tool}" "${binary}"
    echo "Stripped QNX example '${built_example}': ${binary}"
  else
    echo "QNX example '${built_example}' built: ${binary}"
  fi
done

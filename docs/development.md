<!--
SPDX-FileCopyrightText: Copyright (c) 2026 Contributors to the Eclipse Foundation
SPDX-License-Identifier: Apache-2.0
-->

# Development

Clone the repository:

```bash
git clone https://github.com/eclipse-opensovd/opensovd-core.git
cd opensovd-core
```

There are two options to set up a build environment:

## Option 1: Dev Container (VS Code)

The repository includes a [Dev Container](.devcontainer/devcontainer.json) configuration that provides a ready-to-use environment with all tools pre-configured.

1. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension in VS Code.
2. Open the project and select **Dev Containers: Reopen in Container**.

The container installs the tools pinned in [`mise.toml`](../mise.toml), the Rust
toolchain from `rust-toolchain.toml` and the git hooks, pre-configures VS Code extensions
(rust-analyzer, ruff, etc.) and forwards port 7690 for the gateway.
The tools live in the `opensovd-core-mise` volume, so rebuilds reuse them, and the
Python environment in `/home/vscode/.venv`, apart from the checkout's `.venv`. It has
no Docker, so run the published-image workflow in [Testing](testing.md) from the host.

## Option 2: Local

Install [mise](https://mise.jdx.dev/getting-started.html) with its shell activation. It
installs the Rust toolchain from `rust-toolchain.toml` and every other tool from
[`mise.toml`](../mise.toml):

```bash
mise trust
mise install
uv sync
mise run install-hooks
```

mise sandboxes the hooks, so on Linux, the dev container included, they need kernel 6.2
or newer with Landlock enabled.

## Option 3: Bazel bootstrap

The repository also includes a Bazel entrypoint backed by `rules_rust` and `crate_universe`. This keeps the Rust workspace native in Bazel instead of shelling out to Cargo for package builds.

Use Bazel 8.6.0 directly or via Bazelisk so the workspace follows the pinned version in `.bazelversion`.

```bash
# Build the gateway through Bazel
bazel build //:opensovd-gateway
```

The Bazel integration builds the gateway and its transitive internal dependencies. Cargo remains the authoritative test workflow.

## Cross-compile for QNX AArch64

Install QNX SDP 7.1 and source its environment script. The pinned Rust
toolchain has no prebuilt QNX standard library, so install `rust-src` and build
the standard library from source. The QNX GCC shim supplies the SDP sysroot,
QNX pthread extensions, and AWS-LC's compile-time ARM capability mode.
The shim and the example cross-compile script are in `scripts/qnx710/`.
The script checks `$HOME/qnx710/qnxsdp-env.sh` first and falls back to
`/opt/qnx710/qnxsdp-env.sh`; set `QNX_ENV_SCRIPT` to use another location.

```bash
rustup component add rust-src
source /path/to/qnxsdp-env.sh
export CC_aarch64_unknown_nto_qnx710="$PWD/scripts/qnx710/qnx-gcc-shim.sh"
export CXX_aarch64_unknown_nto_qnx710="$PWD/scripts/qnx710/qnx-gcc-shim.sh"
export CARGO_TARGET_AARCH64_UNKNOWN_NTO_QNX710_LINKER="$PWD/scripts/qnx710/qnx-gcc-shim.sh"
RUSTC_BOOTSTRAP=1 cargo build \
  -Z build-std=std,panic_abort \
  --release \
  --target aarch64-unknown-nto-qnx710 \
  -p opensovd-gateway \
  --no-default-features \
  --features jsonschema,json-preserve-order,mock,tls,mdns
```

The build uses AWS-LC. The executable is written to
`target/aarch64-unknown-nto-qnx710/release/opensovd-gateway`.

To cross-compile server examples, use `scripts/qnx710/x-compile-qnx-examples.sh`:

```bash
# One server example
scripts/qnx710/x-compile-qnx-examples.sh -e bulkdata

# All server examples, including mtls (enables tls)
scripts/qnx710/x-compile-qnx-examples.sh -a

# The client example
scripts/qnx710/x-compile-qnx-examples.sh -client
```

Pass `-c` to clean the QNX target directory before building or `-s` to strip
the produced example binary or binaries.

When dependency versions change, refresh the generated crate-universe lock metadata with:

```bash
CARGO_BAZEL_REPIN=1 bazel sync --only=crate_index
```

# Host waypipe-rs for Linux peers (SLICEANDDICE, etc.).
#
# Wawona's macOS/iOS recipes are heavily patched (IOSurface / staticlib). The
# remote SSH *server* must be ordinary waypipe-rs that speaks the same wire
# protocol — nixpkgs already packages mstoeckl/waypipe v0.11 (Rust). Prefer that
# build, and default to --no-gpu so dmabuf/Vulkan server-conn does not SIGSEGV
# when talking to Wawona's compositor (observed on SLICEANDDICE).
#
# Idempotent: Wawona's client already passes --no-gpu over SSH; clap rejects
# duplicate flags ("cannot be used multiple times"), so only inject when absent.
# Use waypipe-rs-unwrapped for GPU/dmabuf.
{
  lib,
  pkgs,
  common ? null,
  buildModule ? null,
  ...
}:

let
  real = pkgs.waypipe;
in
pkgs.runCommand "waypipe-rs-wawona" {
  pname = "waypipe";
  version = real.version or "0.11.0";
  meta = (real.meta or { }) // {
    description = "waypipe-rs for Wawona peers (defaults to --no-gpu / SHM)";
  };
} ''
  mkdir -p $out/bin $out/share/waypipe-rs
  ln -s ${real}/bin/waypipe $out/bin/waypipe-rs-unwrapped
  cat > $out/bin/waypipe <<'EOF'
#! /usr/bin/env bash
set -euo pipefail
real="@real@"
has_no_gpu=0
for arg in "$@"; do
  case "$arg" in
    --no-gpu) has_no_gpu=1 ;;
  esac
done
if [ "$has_no_gpu" -eq 0 ]; then
  exec "$real" --no-gpu "$@"
else
  exec "$real" "$@"
fi
EOF
  substituteInPlace $out/bin/waypipe --replace-fail '@real@' ${real}/bin/waypipe
  chmod +x $out/bin/waypipe
  printf '%s\n' \
    "wawona-peer waypipe-rs (wraps nixpkgs ${real.pname or "waypipe"} ${real.version or ""})" \
    "Default: --no-gpu (SHM), skipped if already on argv." \
    "Use waypipe-rs-unwrapped for GPU/dmabuf." \
    > $out/share/waypipe-rs/README
''

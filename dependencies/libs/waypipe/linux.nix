# Host waypipe-rs for Linux peers (SLICEANDDICE, etc.).
#
# Wawona's macOS/iOS recipes are heavily patched (IOSurface / staticlib). The
# remote SSH *server* must be ordinary waypipe-rs that speaks the same wire
# protocol — nixpkgs already packages mstoeckl/waypipe v0.11 (Rust). Prefer that
# build, and wrap it with --no-gpu by default so dmabuf/Vulkan server-conn does
# not SIGSEGV when talking to Wawona's compositor (observed on SLICEANDDICE).
#
# Users who need GPU transport can call `waypipe-rs-unwrapped` or pass flags
# after disabling the wrapper.
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
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta = (real.meta or { }) // {
    description = "waypipe-rs for Wawona peers (defaults to --no-gpu / SHM)";
  };
} ''
  mkdir -p $out/bin $out/share/waypipe-rs
  ln -s ${real}/bin/waypipe $out/bin/waypipe-rs-unwrapped
  makeWrapper ${real}/bin/waypipe $out/bin/waypipe \
    --add-flags --no-gpu
  printf '%s\n' \
    "wawona-peer waypipe-rs (wraps nixpkgs ${real.pname or "waypipe"} ${real.version or ""})" \
    "Default: --no-gpu (SHM). Use waypipe-rs-unwrapped for GPU/dmabuf." \
    > $out/share/waypipe-rs/README
''

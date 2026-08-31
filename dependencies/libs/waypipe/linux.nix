# Host waypipe-rs for Linux peers (SSH remote / VM guests).
#
# Wawona's macOS/iOS recipes are heavily patched (IOSurface / staticlib). The
# remote SSH *server* must be ordinary waypipe-rs that speaks the same wire
# protocol — nixpkgs already packages mstoeckl/waypipe v0.11 (Rust).
#
# GPU/dmabuf is allowed by default so OpenGL/Vulkan clients work over waypipe.
# SHM fallback is opt-in: Wawona Machines "Disable GPU" (WaypipeNoGpu) passes
# `--no-gpu` on the client argv; peers honour that negotiation. Do not wrap
# every peer invocation with `--no-gpu` here.
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
    description = "waypipe-rs for Wawona peers (GPU/dmabuf allowed; Disable GPU → --no-gpu)";
  };
} ''
  mkdir -p $out/bin $out/share/waypipe-rs
  ln -s ${real}/bin/waypipe $out/bin/waypipe
  ln -s ${real}/bin/waypipe $out/bin/waypipe-rs-unwrapped
  printf '%s\n' \
    "wawona-peer waypipe-rs (nixpkgs ${real.pname or "waypipe"} ${real.version or ""})" \
    "GPU/dmabuf allowed by default." \
    "Pass --no-gpu (Wawona Disable GPU) for SHM-only transport." \
    > $out/share/waypipe-rs/README
''

# wwn-waypipe

[![CI](https://github.com/Wawona/wwn-waypipe/actions/workflows/ci.yml/badge.svg)](https://github.com/Wawona/wwn-waypipe/actions/workflows/ci.yml)

Wawona's [waypipe](https://gitlab.freedesktop.org/mstoeckl/waypipe) port for remote
Wayland display, cross-compiled for Apple platforms (IOSurface + Mach-port transport)
and Android (AHardwareBuffer GBM via wwn-iland, same #86 high-bit modifier).

Patch-overlay model: pristine waypipe `v0.11.0` is pinned in `waypipe-src.nix` and
patched at build time (`patch-waypipe-source.sh`, `patch-waypipe-android.sh`).
Built with [wwn-toolchain](https://github.com/Wawona/wwn-toolchain).

## Use

```nix
inputs.wwn-waypipe.url = "github:Wawona/wwn-waypipe";

registry = wwn-toolchain.lib.baseRegistry // wwn-waypipe.registryFragment;

# Patched source tree for the in-process Rust backend Cargo path-dep:
patched = wwn-waypipe.lib.mkPatchedSrc {
  inherit pkgs;
  platform = "macos";
  patchScript = wwn-waypipe.lib.patchScripts.source;  # or .android
};
```

## Standalone build

```sh
nix build .#waypipe-ios
nix build .#waypipe-macos   # IOSurface dmabuf + --socket-fds (SplitFD)
nix build .#waypipe-linux   # Linux peer: nixpkgs waypipe-rs (GPU allowed)
```

### Linux peer host

Install ordinary waypipe-rs 0.11.0 on the SSH peer. GPU/dmabuf is allowed so
OpenGL/Vulkan clients work. Wawona passes `--no-gpu` only when Machines
**Disable GPU** is on.

```sh
nix profile install github:Wawona/wwn-waypipe/development#waypipe --priority 3
which waypipe
```

## Wawona Swinging Bridge remote forwarding

See Wawona docs for Swinging Bridge. Buffer transport prefers zero-copy dmabuf
(IOSurface on macOS, `AHardwareBuffer` on Android via wwn-iland GBM — same #86
high-bit modifier convention). **Disable GPU** forces SHM/`--no-gpu`.

## License

MIT (same as upstream waypipe where applicable; Wawona patches under the
project license).

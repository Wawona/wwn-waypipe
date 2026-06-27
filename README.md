# wwn-waypipe

Wawona's [waypipe](https://gitlab.freedesktop.org/mstoeckl/waypipe) port for remote
Wayland display, cross-compiled for Apple platforms (IOSurface + Mach-port transport,
no GBM/DMA-BUF/Vulkan) and Android.

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
nix build .#waypipe-macos
```

## License

MIT for the Wawona Nix packaging / patches (see `LICENSE`). waypipe itself is GPL-3.0;
its source is fetched from upstream at build time.

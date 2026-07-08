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

## anowaW remote forwarding

The [wwn-anowaW](https://github.com/Wawona/wwn-anowaW) app bridge turns a native
macOS/Android app into an ordinary Wayland client (one `xdg_toplevel` per
window, frames pushed as `wl_buffer`s). Because it speaks plain Wayland, waypipe
can forward those surfaces to a **remote Linux compositor** with no protocol
changes: point anowaW at waypipe's local client socket instead of the nested
Weston socket, and waypipe tunnels the surface over SSH exactly like any other
client.

waypipe publishes a client-side proxy socket; the host app then starts the
anowaW bridge against **that** socket name (the `socket_name` argument of
`anowaw_start`, normally `wawona-nested`) instead of the local nested Weston
socket. Bridged app windows then appear on the *remote* machine's compositor:

```sh
# On the local device, waypipe proxies a client socket over SSH to the remote:
waypipe --socket "$XDG_RUNTIME_DIR/waypipe-anowaw" \
        ssh user@remote-linux weston-desktop-shell &
# Host app: anowaw_start(socket_name = "waypipe-anowaw", ...)
# (Wawona passes this instead of "wawona-nested" when remote mode is selected.)
```

Buffer transport degrades gracefully: anowaW prefers zero-copy dmabuf
(IOSurface on macOS, `AHardwareBuffer` on Android), but when waypipe runs with
`--no-gpu` — or the remote has no GPU import path — both waypipe and the anowaW
core fall back to the always-available `wl_shm` copy path, so remote forwarding
works even on headless/software compositors. This is the same SHM fallback the
bridge uses locally against software Weston.

> Scope: the local desktop machine anowaW attaches to must still be a local-only
> nested-Weston compositor (Wawona enforces this filter). Remote forwarding is an
> additional transport for the *bridged app surface*, not a way to select a
> remote machine as the App Bridge desktop.

## License

MIT for the Wawona Nix packaging / patches (see `LICENSE`). waypipe itself is GPL-3.0;
its source is fetched from upstream at build time.

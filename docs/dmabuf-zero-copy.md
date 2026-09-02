# waypipe AHB / IOSurface zero-copy notes (dma-buf-zero-copy campaign)

Apple: IOSurface dmabuf path in `dependencies/libs/waypipe/macos.nix` (high-bit
modifier). Android: `android.nix` builds with `--features dmabuf,video,gbmfallback`
and iland GBM for AHardwareBuffer. Linux: real dma-buf passthrough; `--no-gpu`
forces SHM (`fallback_shm` on purpose).

When touching buffer transport, log impact with `wwn.dmabuf` / waypipe traces
and keep GPU sessions on `copy=zero`.

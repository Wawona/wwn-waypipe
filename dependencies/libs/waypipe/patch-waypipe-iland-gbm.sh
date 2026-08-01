#!/bin/bash
# Wire waypipe GBM fallback to wwn-iland (#86 IOSurface/AHB).
set -e
# Apple + Android GPU targets use waypipe's real GBM fallback over wwn-iland.
# Buffer identity is carried in iland's private high-bit modifier (IOSurface ID
# on Apple, AHB registry id on Android — #86). The placeholder fd only satisfies
# the linux-dmabuf wire shape. Both endpoints are in-process, so lookup imports
# the same allocation without a second compositor-facing copy.
if [ -f "wrap-gbm/build.rs" ] && [ -f "src/gbm.rs" ] && [ -f "src/util.rs" ]; then
  python3 <<'ILAND_GBM_PATCH'
from pathlib import Path

build = Path("wrap-gbm/build.rs")
text = build.read_text()
text = text.replace(
    '"gbm_import_fd_data",\n        "gbm_bo_transfer_flags",',
    '"gbm_import_fd_data",\n        "gbm_import_fd_modifier_data",\n        "gbm_bo_transfer_flags",',
    1,
)
text = text.replace(
    'let vars = &["GBM_BO_IMPORT_FD"];',
    'let vars = &["GBM_BO_IMPORT_FD", "GBM_BO_IMPORT_FD_MODIFIER"];',
    1,
)
anchor = "    depfile_to_cargo(&dep_path);\n"
static_loader = r'''    {
        let os = std::env::var("CARGO_CFG_TARGET_OS").ok();
        let vendor = std::env::var("CARGO_CFG_TARGET_VENDOR").ok();
        let use_static = os.as_deref() == Some("android")
            || (vendor.as_deref() == Some("apple") && os.as_deref() != Some("macos"));
        if use_static {
            let generated = std::fs::read_to_string(&out_path).unwrap();
            let compact = "let library = ::libloading::Library::new(path)?;";
            let spaced = "let library = :: libloading :: Library :: new (path) ? ;";
            let replacement = "let _ = path; let library: ::libloading::Library = ::libloading::os::unix::Library::this().into();";
            let generated = if generated.contains(compact) {
                generated.replacen(compact, replacement, 1)
            } else if generated.contains(spaced) {
                generated.replacen(spaced, replacement, 1)
            } else {
                panic!("bindgen GBM loader anchor changed");
            };
            std::fs::write(&out_path, generated).unwrap();
        }
    }
'''
if static_loader not in text:
    if anchor not in text:
        raise SystemExit("wrap-gbm build anchor missing")
    text = text.replace(anchor, static_loader + anchor, 1)
build.write_text(text)

util = Path("src/util.rs")
text = util.read_text()
list_anchor = "pub fn list_render_device_ids() -> Vec<u64> {\n"
list_insert = '''pub fn list_render_device_ids() -> Vec<u64> {
    #[cfg(any(target_vendor = "apple", target_os = "android"))]
    {
        return vec![0x57574e49];
    }
'''
if list_anchor not in text:
    raise SystemExit("list_render_device_ids anchor missing")
text = text.replace(list_anchor, list_insert, 1)
open_anchor = "pub fn drm_open_render(dev_id: u64, rdrw: bool) -> Result<OwnedFd, String> {\n"
open_insert = '''pub fn drm_open_render(dev_id: u64, rdrw: bool) -> Result<OwnedFd, String> {
    #[cfg(any(target_vendor = "apple", target_os = "android"))]
    {
        let _ = (dev_id, rdrw);
        return std::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/null")
            .map(Into::into)
            .map_err(|x| tag!("Failed to open iland virtual render fd: {}", x));
    }
'''
if open_anchor not in text:
    raise SystemExit("drm_open_render anchor missing")
text = text.replace(open_anchor, open_insert, 1)
util.write_text(text)

gbm = Path("src/gbm.rs")
text = gbm.read_text()
text = text.replace(
    '''        _ => {
            return Err(tag!(
                "Importing is only supported with invalid/unspecified or linear modifier, not {:#016x}", plane.modifier,
            ));
        }''',
    '''        m if cfg!(any(target_vendor = "apple", target_os = "android")) && (m & 0x8000_0000_0000_0000) != 0 =>
            gbm_bo_flags_GBM_BO_USE_RENDERING,
        _ => {
            return Err(tag!(
                "Importing is only supported with invalid/unspecified, linear, or iland IOSurface modifier, not {:#016x}", plane.modifier,
            ));
        }''',
    1,
)
legacy_import = '''        let bo = device.bindings.gbm_bo_import(
            device.device,
            GBM_BO_IMPORT_FD,
            &mut data as *mut gbm_import_fd_data as *mut c_void,
            flags,
        );'''
apple_import = '''        #[cfg(any(target_vendor = "apple", target_os = "android"))]
        let bo = {
            let mut modifier_data = gbm_import_fd_modifier_data {
                width,
                height,
                format: drm_format,
                num_fds: 1,
                fds: [data.fd, -1, -1, -1],
                strides: [stride as i32, 0, 0, 0],
                offsets: [0, 0, 0, 0],
                modifier,
            };
            device.bindings.gbm_bo_import(
                device.device,
                GBM_BO_IMPORT_FD_MODIFIER,
                &mut modifier_data as *mut gbm_import_fd_modifier_data as *mut c_void,
                flags,
            )
        };
        #[cfg(not(any(target_vendor = "apple", target_os = "android")))]
        let bo = device.bindings.gbm_bo_import(
            device.device,
            GBM_BO_IMPORT_FD,
            &mut data as *mut gbm_import_fd_data as *mut c_void,
            flags,
        );'''
if legacy_import not in text:
    raise SystemExit("GBM import anchor missing")
text = text.replace(legacy_import, apple_import, 1)
plane_anchor = '''        /* No failure mechanism is documented */
        let stride = (device.bindings.gbm_bo_get_stride)(bo);
        Ok(('''
plane_insert = '''        /* No failure mechanism is documented */
        let stride = (device.bindings.gbm_bo_get_stride)(bo);
        let exported_modifier = if cfg!(any(target_vendor = "apple", target_os = "android")) {
            (device.bindings.gbm_bo_get_modifier)(bo)
        } else {
            actual_mod
        };
        Ok(('''
if plane_anchor not in text:
    raise SystemExit("GBM export anchor missing")
text = text.replace(plane_anchor, plane_insert, 1)
text = text.replace(
    '''                modifier: actual_mod,
            }],''',
    '''                modifier: exported_modifier,
            }],''',
    1,
)
gbm.write_text(text)
ILAND_GBM_PATCH
  echo "✓ Wired waypipe GBM fallback to iland IOSurface/AHB buffers (#86)"
fi

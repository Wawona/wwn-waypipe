{
  description = "wwn-waypipe: Wawona's waypipe-rs port for remote Wayland display, cross-compiled for Apple platforms (IOSurface/Mach-port transport) and Android, plus the patched-source builder for the in-process Rust backend.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    wwn-toolchain.url = "github:Wawona/wwn-toolchain";
    wwn-toolchain.inputs.nixpkgs.follows = "nixpkgs";
    wwn-toolchain.inputs.rust-overlay.follows = "rust-overlay";
    # SSH stack (libssh2 + streamlocal patch used by the iOS in-process
    # transport) lives in wwn-ssh since it was split out of wwn-toolchain.
    wwn-ssh.url = "github:Wawona/wwn-ssh";
    wwn-ssh.inputs.nixpkgs.follows = "nixpkgs";
    wwn-ssh.inputs.rust-overlay.follows = "rust-overlay";
    wwn-ssh.inputs.wwn-toolchain.follows = "wwn-toolchain";
  };

  outputs = { self, nixpkgs, rust-overlay, wwn-toolchain, wwn-ssh, ... }:
    let
      darwinSystems = [ "x86_64-darwin" "aarch64-darwin" ];
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      allSystems = darwinSystems ++ linuxSystems;
      forAll = nixpkgs.lib.genAttrs allSystems;
      inherit (wwn-toolchain.lib) withPlatformVariants baseRegistry mkToolchains;

      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
        config = { allowUnfree = true; allowUnsupportedSystem = true; android_sdk.accept_license = true; };
      };

      wpDir = ./dependencies/libs/waypipe;
    in
    {
      registryFragment = {
        waypipe = withPlatformVariants {
          android = wpDir + "/android.nix";
          wearos = wpDir + "/wearos.nix";
          ios = wpDir + "/ios.nix";
          tvos = wpDir + "/tvos.nix";
          ipados = wpDir + "/ios.nix";
          visionos = wpDir + "/visionos.nix";
          watchos = wpDir + "/watchos.nix";
          macos = wpDir + "/macos.nix";
        };
      };

      # Consumed by Wawona's flake for the Rust backend's patched waypipe path-dep.
      lib = {
        waypipeSrc = pkgs: import (wpDir + "/waypipe-src.nix") { inherit pkgs; };
        patchedSrcRecipe = wpDir + "/waypipe-patched-src.nix";
        patchScripts = {
          source = wpDir + "/patch-waypipe-source.sh";
          android = wpDir + "/patch-waypipe-android.sh";
        };
        mkPatchedSrc = { pkgs, platform, patchScript }:
          pkgs.callPackage (wpDir + "/waypipe-patched-src.nix") {
            waypipe-src = import (wpDir + "/waypipe-src.nix") { inherit pkgs; };
            inherit patchScript platform;
          };
      };

      packages = forAll (system:
        let
          pkgs = pkgsFor system;
          tc = mkToolchains { inherit pkgs; registry = baseRegistry // wwn-ssh.registryFragment // self.registryFragment; };
          isDarwin = builtins.elem system darwinSystems;
        in
        (if isDarwin then {
          waypipe-ios = tc.buildForIOS "waypipe" { };
          waypipe-macos = tc.buildForMacOS "waypipe" { };
        } else { }));

      formatter = forAll (system: (pkgsFor system).nixfmt-rfc-style);
    };
}

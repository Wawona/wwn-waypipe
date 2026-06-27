# Pristine upstream waypipe source pin (patch-overlay model). Patched at build
# time by patch-waypipe-source.sh / patch-waypipe-android.sh via
# waypipe-patched-src.nix. Kept here so wwn-waypipe owns the source pin and so
# Wawona resolves it against the shared nixpkgs.
{ pkgs }:
pkgs.fetchFromGitLab {
  owner = "mstoeckl";
  repo = "waypipe";
  rev = "v0.11.0";
  sha256 = "sha256-Tbd/yY90yb2+/ODYVL3SudHaJCGJKatZ9FuGM2uAX+8=";
}

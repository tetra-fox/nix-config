{pkgs, ...}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = [
      (final: prev: {
        inherit
          (prev.lixPackageSets.stable)
          nixpkgs-review
          nix-eval-jobs
          nix-fast-build
          colmena
          ;
      })

      # patool 4.0.5's mime tests assume the pre-landlock behavior of file(1);
      # nixpkgs enabled a landlock sandbox in file that makes libmagic report
      # application/x-bzip2 for a .tar.bz2, so the tests fail (NixOS/nixpkgs#540025).
      # the fix is on the file side (#540742, merged to staging 2026-07-11) and
      # hasn't reached our channel yet. the code is fine, only the tests are stale,
      # so drop the check until the file fix lands. bottles pulls patool in
      (final: prev: {
        pythonPackagesExtensions =
          prev.pythonPackagesExtensions
          ++ [
            (pyFinal: pyPrev: {
              patool = pyPrev.patool.overridePythonAttrs (_: {doCheck = false;});
            })
          ];
      })
    ];
  };

  nix.package = pkgs.lixPackageSets.stable.lix;
}

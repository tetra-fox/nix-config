{...}: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      cores = 0; # use all cores per build
      max-jobs = "auto"; # parallel derivations

      # in-operation GC safety valve: when free space drops below min-free during a
      # build or a pushed-closure copy, nix frees paths until max-free is available
      # rather than failing with ENOSPC. matters on the small fleet VMs -- a big closure
      # pushed after weeks of nixpkgs drift can't fill the disk mid-copy and wedge.
      min-free = 536870912; # 512 MiB: start freeing below this
      max-free = 3221225472; # 3 GiB: free up to this much when triggered

      # let wheel members push unsigned store paths via `nixos-rebuild --target-host`
      trusted-users = ["root" "@wheel"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      options = "--delete-older-than 7d";
    };
    # periodic store dedupe
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
  };
}

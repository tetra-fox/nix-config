# nix daemon settings shared by the linux (system.nix) and darwin (darwin.nix)
# faces of this module; gc/optimise scheduling and the admin group differ per
# platform so those live in the platform files
_: {
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    cores = 0;
    max-jobs = "auto";

    # frees paths mid-build instead of failing with ENOSPC on the small fleet VMs
    min-free = 536870912;
    max-free = 3221225472;
  };
}

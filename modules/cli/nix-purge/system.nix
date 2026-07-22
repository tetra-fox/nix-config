# the `nix-purge` wrapper, on every host (linux and darwin, servers included)
# rather than in the shell config, so it works over ssh and under any shell
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nix-purge";
      # nix and sudo deliberately come from the system PATH: a store-pinned nix
      # can disagree with the running daemon, and only the system sudo is setuid
      runtimeInputs = [pkgs.coreutils pkgs.gawk];
      text = builtins.readFile ./_nix-purge.sh;
    })
  ];
}

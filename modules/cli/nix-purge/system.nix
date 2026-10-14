# a system package rather than a shell function, so it works under any shell
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nix-purge";
      # nix and sudo come from the system PATH: a pinned nix can disagree with the
      # daemon, and only the system sudo is setuid
      runtimeInputs = [pkgs.coreutils pkgs.gawk];
      text = builtins.readFile ./_nix-purge.sh;
    })
  ];
}

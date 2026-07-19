# heavier scan/capture tools. mtr and dig stay in the base profile since
# every host wants those for day-to-day debugging
{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      nmap
      tcpdump
      iperf3
    ]
    # ethernet-layer tooling only exists on linux
    ++ lib.optionals stdenv.isLinux [ethtool];
}

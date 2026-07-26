# heavier scan/capture tools. mtr and dig stay in the base profile since
# every host wants those for day-to-day debugging
{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      iperf3
      ldns # drill, which prints the dnssec chain dig only summarises
      nmap
      socat
      tcpdump
      whois
    ]
    # ethernet and conntrack layers only exist on linux, and nixpkgs marks
    # traceroute linux-only too (macos ships its own in /usr/sbin)
    ++ lib.optionals stdenv.isLinux [
      # what nftables actually holds in state, for when a rule reads correct but traffic still drops
      conntrack-tools
      ethtool
      traceroute
    ];
}

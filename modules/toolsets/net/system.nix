# mtr and dig are in the base profile
{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      iperf3
      ldns # drill prints the dnssec chain dig only summarises
      nmap
      socat
      tcpdump
      whois
    ]
    # macos ships its own traceroute
    ++ lib.optionals stdenv.isLinux [
      conntrack-tools
      ethtool
      traceroute
    ];
}

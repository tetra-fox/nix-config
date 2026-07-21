# source-scoped nftables accept rules: one "ip saddr <ip> tcp dport <ports> accept" line
# per source ip. rules like these need the nftables firewall backend (the base profile
# enables it fleet-wide). a single port renders bare, several render as a port set.
{lib}: ips: ports: let
  dport =
    if lib.length ports == 1
    then toString (lib.head ports)
    else "{ ${lib.concatMapStringsSep ", " toString ports} }";
in
  lib.concatMapStringsSep "\n" (ip: "ip saddr ${ip} tcp dport ${dport} accept") ips

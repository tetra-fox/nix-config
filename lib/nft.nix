# needs the nftables firewall backend, which the base profile enables
{lib}: ips: ports: let
  dport =
    if lib.length ports == 1
    then toString (lib.head ports)
    else "{ ${lib.concatMapStringsSep ", " toString ports} }";
in
  lib.concatMapStringsSep "\n" (ip: "ip saddr ${ip} tcp dport ${dport} accept") ips

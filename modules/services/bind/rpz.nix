# RPZ blocklist refresh: fetch each configured list, write it as an RPZ zone file, reload named.
# bind's RPZ (response policy zones) is the "official" DNS blocking mechanism -- a policy zone
# whose records rewrite answers; `domain CNAME .` means NXDOMAIN. a daily timer keeps the lists
# fresh without a rebuild; the list content is runtime state, the fetch logic is declared here.
# the lists themselves come from lab.bind.rpzLists, so this is site-agnostic.
#
# per-list `format`:
#   rpz   -- already an RPZ zone (SOA + NS + domain/*.domain CNAME . pairs), fetched verbatim.
#   hosts -- a 0.0.0.0 hosts file, converted: a header (SOA + NS), then per domain a
#            `domain CNAME .` (block the name) and `*.domain CNAME .` (block everything under it).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.bind;
  rpzDir = "/var/lib/named/rpz";

  # one fetch+convert+reload block per configured list. fetch to a temp file first so a failed
  # download (curl --fail exits non-zero, set -e aborts before the mv) leaves the previous good
  # file in place. then rndc reload the policy zone (doesn't drop the cache a restart would).
  mkFetch = l: let
    convert =
      if l.format == "rpz"
      then ''curl --fail --silent --show-error --location --max-time 60 "${l.url}" -o "$tmp/${l.name}"''
      else ''
        {
          # $TTL is literal RPZ zone-file syntax, not a shell variable; single quotes keep it literal
          printf '$TTL 30\n@ IN SOA localhost. hostmaster.localhost. 1 3600 900 604800 30\n  IN NS localhost.\n'
          curl --fail --silent --show-error --location --max-time 60 "${l.url}" \
            | awk '$1 == "0.0.0.0" && NF >= 2 { printf "%s CNAME .\n*.%s CNAME .\n", $2, $2 }'
        } > "$tmp/${l.name}"
      '';
  in ''
    ${convert}
    mv "$tmp/${l.name}" "$dir/${l.name}"
    rndc reload ${l.name}
  '';

  refresh = pkgs.writeShellApplication {
    name = "bind-rpz-refresh";
    runtimeInputs = [pkgs.curl pkgs.gawk pkgs.bind];
    # SC2016: the printf above emits literal `$TTL` (RPZ zone syntax), single quotes are correct.
    excludeShellChecks = ["SC2016"];
    text = ''
      set -euo pipefail
      dir="${rpzDir}"
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT

      ${lib.concatMapStrings mkFetch cfg.rpzLists}
    '';
  };
in {
  config = lib.mkIf (cfg.enable && cfg.rpzLists != []) {
    systemd.services.bind-rpz-refresh = {
      description = "fetch RPZ blocklists and reload named";
      after = ["network-online.target" "bind.service"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe refresh;
        # rndc needs the rndc key (root/named readable) and the files are named-owned; run as
        # named so both the writes and the reload have the right ownership/credentials.
        User = "named";
        Group = "named";
        ReadWritePaths = [rpzDir];
      };
    };

    systemd.timers.bind-rpz-refresh = {
      description = "daily RPZ blocklist refresh";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        # also run a few minutes after boot: the zone files ship as empty stubs (so named can
        # start), so without this a freshly-booted resolver blocks nothing until the next daily
        # tick. delay so the network and named are up first.
        OnBootSec = "3min";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}

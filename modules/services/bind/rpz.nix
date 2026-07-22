# RPZ blocklist refresh: fetch each configured list, write it as an RPZ zone file, reload named.
# an RPZ is a policy zone whose records rewrite answers; `domain CNAME .` means NXDOMAIN.
#
# per-list `format`:
#   rpz   -- already an RPZ zone, fetched verbatim.
#   hosts -- a 0.0.0.0 hosts file, converted to `domain CNAME .` + `*.domain CNAME .` per entry.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.bind;
  inherit (import ./_rpz-common.nix) rpzDir rpzStubText;

  # fetch to a temp file first so a failed download (curl --fail + set -e aborts before the mv)
  # leaves the previous good file in place.
  mkFetch = l: let
    convert =
      if l.format == "rpz"
      then ''curl --fail --silent --show-error --location --max-time 60 "${l.url}" -o "$tmp/${l.name}"''
      else ''
        {
          # the shared seed stub ($TTL etc is zone-file syntax; escapeShellArg keeps it literal)
          printf '%s' ${lib.escapeShellArg rpzStubText}
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
    # SC2016 fires on the single-quoted `$TTL` printf above, which is intentional (see there).
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
        # run as named: the rndc key is named-readable and the zone files must be named-owned.
        User = "named";
        Group = "named";
        ReadWritePaths = [rpzDir];
      };
    };

    systemd.timers.bind-rpz-refresh = {
      description = "daily RPZ blocklist refresh";
      wantedBy = ["timers.target"];
      timerConfig = {
        # servers are UTC. 12:00 plus the random hour is 4a-6a pacific
        # see SCHEDULE.md
        OnCalendar = "12:00";
        # run after boot too, else a freshly-booted resolver (empty stubs) blocks nothing until
        # the next daily tick. 3min so network + named are up first.
        OnBootSec = "3min";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.bind;
  inherit (import ./_rpz-common.nix) rpzDir rpzStubText;

  # a failed fetch aborts before the mv, keeping the previous good file
  mkFetch = l: let
    convert =
      if l.format == "rpz"
      then ''curl --fail --silent --show-error --location --max-time 60 "${l.url}" -o "$tmp/${l.name}"''
      else ''
        {
          printf '%s' ${lib.escapeShellArg rpzStubText}
          # `CNAME .` answers NXDOMAIN
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
    # the stub's `$TTL` is zone-file syntax, meant to stay unexpanded
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
        # the rndc key is named-readable and the zone files must be named-owned
        User = "named";
        Group = "named";
        ReadWritePaths = [rpzDir];
      };
    };

    systemd.timers.bind-rpz-refresh = {
      description = "daily RPZ blocklist refresh";
      wantedBy = ["timers.target"];
      timerConfig = {
        # 12:00 UTC plus the random hour, see SCHEDULE.md
        OnCalendar = "12:00";
        # a fresh boot has only empty stubs, so don't wait for the daily tick
        OnBootSec = "3min";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };
  };
}

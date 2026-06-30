# RPZ blocklist refresh: fetch the lists, write them as RPZ zone files, reload named. bind's
# RPZ (response policy zones) is the "official" DNS blocking mechanism -- a policy zone whose
# records rewrite answers; `domain CNAME .` means NXDOMAIN. a daily timer keeps the lists fresh
# without a rebuild; the list content is runtime state, the fetch logic is declared here.
#
# two sources:
#   OISD big  -- already RPZ format (SOA + NS + domain/*.domain CNAME . pairs), fetched as-is.
#                https://big.oisd.nl/rpz
#   VRChat    -- plain hosts format (0.0.0.0 domain), converted to RPZ. owner renamed
#                Luois45 -> louisa-uno; raw.githubusercontent doesn't redirect, so the URL
#                must use louisa-uno or it 404s. small + frozen (last update jan 2024).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.bind;
  rpzDir = "/var/lib/named/rpz";

  oisdUrl = "https://big.oisd.nl/rpz";
  vrchatUrl = "https://raw.githubusercontent.com/louisa-uno/VRChatAnalyticsBlocklist/main/hosts.txt";

  refresh = pkgs.writeShellApplication {
    name = "bind-rpz-refresh";
    runtimeInputs = [pkgs.curl pkgs.gawk pkgs.bind];
    # SC2016: the printf below emits literal `$TTL` (RPZ zone syntax), single quotes are correct.
    excludeShellChecks = ["SC2016"];
    text = ''
      set -euo pipefail
      dir="${rpzDir}"
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT

      # OISD ships a full RPZ zone; take it verbatim. fetch to temp first so a failed download
      # (curl --fail exits non-zero, set -e aborts before the mv) leaves the previous good file.
      curl --fail --silent --show-error --location --max-time 60 "${oisdUrl}" -o "$tmp/oisd.rpz"

      # VRChat is hosts format. build an RPZ zone: a header (SOA + NS), then per domain a
      # `domain CNAME .` (block the name) and `*.domain CNAME .` (block everything under it),
      # matching how OISD pairs them. guard on a leading 0.0.0.0 so comments/blanks emit nothing.
      {
        # $TTL is literal RPZ zone-file syntax, not a shell variable; single quotes keep it literal
        printf '$TTL 30\n@ IN SOA localhost. hostmaster.localhost. 1 3600 900 604800 30\n  IN NS localhost.\n'
        curl --fail --silent --show-error --location --max-time 60 "${vrchatUrl}" \
          | awk '$1 == "0.0.0.0" && NF >= 2 { printf "%s CNAME .\n*.%s CNAME .\n", $2, $2 }'
      } > "$tmp/vrchat.rpz"

      mv "$tmp/oisd.rpz" "$dir/oisd.rpz"
      mv "$tmp/vrchat.rpz" "$dir/vrchat.rpz"

      # reload just the policy zones (named picks up the new files); rndc reload <zone> doesn't
      # drop the cache the way a full restart would.
      rndc reload oisd.rpz
      rndc reload vrchat.rpz
    '';
  };
in {
  config = lib.mkIf cfg.enable {
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

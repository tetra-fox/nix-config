# fairlane-specific resolver facts: the RPZ blocklists + zone assembly live in _dns-common.nix
# (proof the bind module is site-agnostic -- a second site keeps only its real deltas). fairlane's
# deltas are the dual-stack WAN knobs and the shared v6 VIP both dns hosts float.
{modules, ...}: {
  imports = [modules.services.bind.system ./_dns-common.nix];

  lab.bind = {
    # fairlane has a real dual-stack WAN (Comcast), so bind must not force -4 (which would refuse
    # every v6 socket, including the v6 VIP). mesa is v4-only and leaves this default false.
    dualStack = true;

    # v6 clients must be in the internal view or they get REFUSED (the default trustedRanges is
    # v4-only). append the LAN ULA range + link-local so the ULA VIP and v6 LAN clients resolve.
    extraTrustedRanges = [
      "fd00::/8" # LAN ULAs (the resolver VIP + v6 clients)
      "fe80::/10" # v6 link-local
    ];

    # the ULA v6 VIP both fairlane dns hosts float (keepalived flips it); the v4 vip lives in
    # hosts/common/dns-host.nix. per-host hostV6 (the v6 heartbeat source) stays in the host file.
    ha.vip6 = "fd00:10::53";
  };
}

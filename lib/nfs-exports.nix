# a store's NFS exports. the pool root is the one fsid=0 v4 root, read-only, so clients mount
# shares by name (`store:/media`) and the names read the same at every site. each share is
# only exported to the ips on its own line, the root grants nothing past directory listing
{lib}: root: shares: let
  # an optional client (e.g. immich before a host provides it) leaves an empty ip list
  exported = lib.filterAttrs (_: s: s.ips != []) shares;
  ips = lib.unique (lib.concatMap (s: s.ips) (lib.attrValues exported));
  line = path: ips: options: "${path} ${lib.concatMapStringsSep " " (ip: "${ip}(${options})") ips}";
in {
  inherit ips;
  # subtree_check on the root: it can sit on the store's root filesystem, and without the check
  # a crafted file handle could reach anything else on that filesystem
  exports =
    lib.concatStringsSep "\n" (
      [(line root ips "ro,sync,subtree_check,fsid=0")]
      ++ lib.mapAttrsToList (name: s: line "${root}/${name}" s.ips s.options) exported
    )
    + "\n";
}

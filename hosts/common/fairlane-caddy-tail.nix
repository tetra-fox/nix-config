# the site-specific Caddyfile blocks the route engine can't derive: the root vhost and the
# HAOS appliance. jellyfin, stats, and the arrs render from lab.topology.routes (the arrs
# lan-only, no authentik at fairlane). imported by edge-host.nix with the host's lab config;
# shared by both edge hosts: stateless clones behind the same VIP serving the identical vhost set.
{lab}: ''
  # public
  ${lab.site.domain} {
  	import log
  	respond "my paws hurt :("
  }

  home.${lab.site.domain} {
  	import log
  	reverse_proxy ${lab.appliances.haosIp}:8123
  }
''

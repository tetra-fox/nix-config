# the site-specific Caddyfile blocks the route engine can't derive: the root vhost, the
# HAOS appliance, and the arr blocks. jellyfin and stats render from lab.topology.routes.
# no authentik at fairlane, so the arr UIs are lan-only proxies straight to the arr host
# ({$ARR_HOST}, the derived arr box); the arr-stack DNATs each netns port onto that host.
# sabnzbd runs on the arr host too (8080). imported by edge-host.nix with the host's lab
# config; shared by both edge hosts: stateless clones behind the same VIP serving the
# identical vhost set.
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

  qb.${lab.site.domain} {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:8888
  	}
  }

  sonarr.${lab.site.domain} {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:8989
  	}
  }

  radarr.${lab.site.domain} {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:7878
  	}
  }

  prowlarr.${lab.site.domain} {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:9696
  	}
  }

  sabnzbd.${lab.site.domain} {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:8080
  	}
  }
''

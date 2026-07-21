# the site-specific Caddyfile blocks the route engine can't derive: the root vhost, the
# HAOS appliance, and the arr blocks. jellyfin and stats render from lab.topology.routes.
# no authentik at fairlane, so the arr UIs are lan-only proxies straight to the arr host
# ({$ARR_HOST}, the derived arr box); the arr-stack DNATs each netns port onto that host.
# sabnzbd runs on the arr host too (8080). shared by both edge hosts: stateless clones
# behind the same VIP serving the identical vhost set.
''
  # public
  fairlane.tetra.cool {
  	import log
  	respond "my paws hurt :("
  }

  home.fairlane.tetra.cool {
  	import log
  	reverse_proxy 192.168.10.215:8123
  }

  qb.fairlane.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:8888
  	}
  }

  sonarr.fairlane.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:8989
  	}
  }

  radarr.fairlane.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:7878
  	}
  }

  prowlarr.fairlane.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:9696
  	}
  }

  sabnzbd.fairlane.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy {$ARR_HOST}:8080
  	}
  }
''

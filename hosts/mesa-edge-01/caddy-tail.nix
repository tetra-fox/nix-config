# the site-specific Caddyfile blocks the route engine can't derive: the root vhost, the two
# appliances with no capability publisher (HAOS, proxmox), and the arr forward_auth block
# (deferred, see TODO). appended after the engine-rendered route vhosts via lab.caddy.staticTail.
# shared by both edge hosts: they're stateless clones behind the same VIP serving the identical
# vhost set, so the tail lives here once instead of being duplicated per edge.
''
  # public
  mesa.tetra.cool {
  	import log
  	respond "my paws hurt :("
  }

  home.mesa.tetra.cool {
  	import log
  	reverse_proxy 10.10.0.20:8123
  }

  pve.mesa.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy https://192.168.10.2:8006 {
  			transport http {
  				tls_insecure_skip_verify
  			}
  		}
  	}
  }

  qb.mesa.tetra.cool,
  sonarr.mesa.tetra.cool,
  radarr.mesa.tetra.cool,
  prowlarr.mesa.tetra.cool,
  sabnzbd.mesa.tetra.cool {
  	route {
  		import lan_only
  		reverse_proxy {$AUTH_UPSTREAM}
  	}
  }
''

# vhosts the route engine can't derive
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

  # no forward_auth: proxmox has its own authentik OIDC realm, a proxy outpost would
  # double-gate the callback and break noVNC and /api2 tokens. proxmox's cert is self-signed
  pve.${lab.site.domain} {
  	route {
  		import lan_only
  		reverse_proxy https://${lab.appliances.proxmoxIp}:8006 {
  			transport http {
  				tls_insecure_skip_verify
  			}
  		}
  	}
  }
''

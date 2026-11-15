# vhosts the route engine can't derive
{
  lib,
  lab,
}: let
  # one vhost per proxmox node, named after it. no forward_auth: proxmox has its own authentik
  # OIDC realm, a proxy outpost would double-gate the callback and break noVNC and /api2 tokens.
  # proxmox's cert is self-signed
  pveVhost = name: ip: ''
    ${name}.${lab.site.domain} {
    	route {
    		import lan_only
    		reverse_proxy https://${ip}:8006 {
    			transport http {
    				tls_insecure_skip_verify
    			}
    		}
    	}
    }
  '';
in ''
  # public
  ${lab.site.domain} {
  	import log
  	respond "my paws hurt :("
  }

  home.${lab.site.domain} {
  	import log
  	reverse_proxy ${lab.appliances.haosIp}:8123
  }

  ${lib.concatStrings (lib.mapAttrsToList pveVhost lab.appliances.proxmoxNodes)}
''

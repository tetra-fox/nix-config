# the site-specific Caddyfile blocks the route engine can't derive: the root vhost and the two
# appliances with no capability publisher (HAOS, proxmox). the arrs now render from
# lab.topology.routes (arr-stack declares them). appended after the engine-rendered route vhosts
# via lab.caddy.staticTail; edge-host.nix imports it with the host's lab config, so the site
# facts (domain, appliance addresses) substitute instead of being restated. shared by both edge
# hosts: they're stateless clones behind the same VIP serving the identical vhost set.
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

  # authentik as well as lan_only: this is the hypervisor UI, so "any RFC1918 source" is
  # too broad a gate on its own. proxmox's own login is behind it, but a compromised host
  # anywhere on the LAN should not even reach that form.
  # tls_insecure_skip_verify stays for now: proxmox serves its own self-signed cert, and
  # trusting it properly means pinning its CA here. the hop is edge -> proxmox on the
  # server VLAN.
  pve.${lab.site.domain} {
  	route {
  		import lan_only
  		import authentik
  		reverse_proxy https://${lab.appliances.proxmoxIp}:8006 {
  			transport http {
  				tls_insecure_skip_verify
  			}
  		}
  	}
  }
''

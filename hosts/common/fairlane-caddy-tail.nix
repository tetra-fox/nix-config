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
''

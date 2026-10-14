# mesa-svc-01 -> mesa, mesa-db-alt-01 -> mesa, hara -> hara
_: name: let
  m = builtins.match "([a-z]+)-[a-z0-9-]+-[0-9]+" name;
in
  if m == null
  then name
  else builtins.head m

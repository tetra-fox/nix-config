# postgres-ha

The HA data-tier server stack: Patroni + etcd + HAProxy + keepalived. A db node sets
`lab.postgres.ha.enable` (instead of `lab.postgres.server.enable`) and `lab.postgres.ha.vip`;
everything else is derived from the site topology.

## How it fits together

```
client ---> VIP:5432 (keepalived floats it across the 3 nodes)
            |
            HAProxy (on whichever node holds the VIP)
            | GET /primary -> 200 only on the leader
            v
            current primary's postgres :5432
                |  Patroni manages: bootstrap, postgresql.conf,
                |  pg_hba (from the DCS), streaming replication, failover
                v
            etcd (3-node consensus, quorum 2/3)
```

- **etcd** -- the consensus store Patroni uses for leader election. 3 nodes co-located on the
  db boxes; tolerates 1 node down. Static bootstrap (`initialClusterState = "new"`).
- **Patroni** -- runs the postmaster itself (not via `services.postgresql`; the two are
  mutually exclusive and the module asserts it). Owns pg_hba via the DCS, so a NixOS-rendered
  pg_hba would be ignored -- the allow-list goes into `settings.bootstrap.dcs.postgresql.pg_hba`.
- **HAProxy** -- on every node, routes `VIP:5432` to whichever backend answers Patroni's REST
  `/primary` with 200 (the leader). Failover is invisible to keepalived. `VIP:5433` -> replicas
  is declared but unused.
- **keepalived** -- floats the VIP. Unicast VRRP (no L2 multicast reliance), all `BACKUP` +
  `noPreempt` so a recovered node doesn't flap the VIP. Tracks HAProxy liveness only.

## The roles contract is shared

This module imports `modules.services.postgres.options` and reads the same `lab.postgres.roles` /
`extraAllowedCidrs` the single-server module uses. Role creation + passwords + db ownership
are applied by a leader-gated `patroni-role-reconcile` oneshot (the successor to the
single-server `postgresql-set-<role>-password.service`): it gates on the local Patroni REST
`/primary` and is a no-op on replicas, so the work happens once per cluster on the primary and
replicates out.

## Endpoint derive

Clients never name a node. They read `dbEndpointIp` from the topology layer, which resolves to
`lab.postgres.ha.vip` when the site is HA, else falls back to the single db server's IP.
So the single-node -> HA cutover swaps the resolved address without touching any client.

## Watchdog / fencing

`softwareWatchdog = true` -> Patroni holds `/dev/watchdog` (kernel softdog) and force-reboots a
primary that loses its etcd lease but can't demote itself -- the split-brain guard. The server
profile's systemd `RuntimeWatchdogSec` is disabled on these nodes (`mkForce "0"`) because a
stock VM has a single watchdog device and the two would contend. Caveat: softdog is a software
watchdog, so a full kernel lockup is outside its reach (a true hardware watchdog would cover it).

## Assumptions / future work

- **No TLS on etcd or the Patroni REST API.** The internal VLAN (10.10.0.0/24) is isolated L2
  with only the db nodes on it -- that isolation is the trust boundary. If the VLAN ever gains
  other tenants, enable etcd peer/client TLS + Patroni REST auth.
- **5433 read pool is unused.** The arr/authentik workload doesn't read-scale; the frontend is
  declared for completeness. Wiring a client to it means accepting replica staleness.

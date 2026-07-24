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
  `/primary` with 200 (the leader). Failover is invisible to keepalived.
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

## Recovery runbook

etcd persists cluster membership (peer addresses) in its data dir's raft state.
`initialCluster` / `initialClusterState = "new"` are read only on the very first start of an
empty data dir; after that etcd ignores them and uses what it persisted. Two failure modes
follow. In both, postgres data is safe -- it lives under `<lab.site.dataDir>/patroni/pgdata`
(`/var/lib/<site>`), separate from `<lab.site.dataDir>/etcd`.

### One node wiped or replaced

The fresh node re-bootstraps a brand-new one-member cluster instead of joining (its
`initialClusterState = "new"` is honored against an empty data dir), while the survivors still
list the dead member. Re-add it instead:

1. On a healthy node: `etcdctl member remove <old-member-id>`, then
   `etcdctl member add <name> --peer-urls=http://<node-ip>:2380`.
2. On the new node: wipe its etcd data dir if it already mis-bootstrapped, and set
   `initialClusterState = "existing"` for its first start (ignored once joined, revert at
   leisure).
3. Start etcd, check `etcdctl endpoint health` across all three, then start patroni.

### All three lose quorum (e.g. the nodes were renumbered)

A config IP change moves the listen addresses, but every node keeps dialing its peers at the
old IPs out of persisted membership: total quorum loss, Patroni frozen (units active but
blind).

1. Back up first: start postgres standalone (`pg_ctl -D <pgdata>` as the patroni user), run
   `pg_dumpall -U postgres`, pull the dumps off-box.
2. Stop patroni and etcd on all three, and verify they stopped. Serial
   stop-verify-wipe-verify per node, not a tight burst -- wiping while etcd is still shutting
   down lets it rewrite `member/` on the way out.
3. Wipe: `rm -rf /var/lib/<site>/etcd`, then recreate the dir with
   `install -d -o etcd -g etcd -m 0700 /var/lib/<site>/etcd`. A plain `systemctl start` does
   not re-run tmpfiles, so a missing dir dies with "mkdir ... permission denied".
4. Start etcd on all three -- fresh cluster on the current IPs.
5. Start patroni on the known-good-data node first; it adopts the existing pgdata and promotes
   (log says "promoted self to leader", not initdb). Verify the data, then start the others --
   they join as streaming replicas.
6. If the VIP changed too, restart haproxy and keepalived -- a stale haproxy stays bound to
   the old VIP.

## Assumptions / future work

- **No TLS on etcd or the Patroni REST API.** The internal VLAN (10.10.0.0/24) is isolated L2
  with only the db nodes on it -- that isolation is the trust boundary. If the VLAN ever gains
  other tenants, enable etcd peer/client TLS + Patroni REST auth.
- **No read pool.** The arr/authentik workload doesn't read-scale, so haproxy only fronts the
  writer. Adding one later means a second `listen` on the VIP checking `/replica` instead of
  `/primary`, and clients that accept replica staleness.

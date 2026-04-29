#!/usr/bin/env bash
# bring up wg0 in MAIN ns first (so the udp socket binds to main ns), then
# move the interface into the vpn netns. wg's socket follows the ns the
# interface was in when first configured - moving the iface AFTER configure
# leaves the socket in main ns (correct, so wg traffic egresses normally),
# while the iface lives in vpn ns (so apps pinned to that ns route through it).
set -ex

PEER=$(< "$CREDENTIALS_DIRECTORY/wg_peer_public_key")
ENDPOINT=$(< "$CREDENTIALS_DIRECTORY/wg_peer_endpoint")
ADDRESS=$(< "$CREDENTIALS_DIRECTORY/wg_address") # may be comma-separated v4 + v6

ip netns exec "$NETNS" ip link del wg0 2>/dev/null || true
ip link del wg0 2>/dev/null || true

ip link add wg0 type wireguard
ip link set wg0 mtu "$WG_MTU"

wg set wg0 \
  private-key "$CREDENTIALS_DIRECTORY/wg_private_key" \
  peer "$PEER" \
    endpoint "$ENDPOINT" \
    preshared-key "$CREDENTIALS_DIRECTORY/wg_preshared_key" \
    allowed-ips 0.0.0.0/0,::/0 \
    persistent-keepalive 15

ip link set wg0 netns "$NETNS"

IFS=, read -ra addrs <<< "$ADDRESS" # ip addr add doesn't take multiples; split comma-separated addrs
for addr in "${addrs[@]}"; do
  [ -n "$addr" ] && ip netns exec "$NETNS" ip addr add "$addr" dev wg0
done

ip netns exec "$NETNS" ip link set wg0 up
ip netns exec "$NETNS" ip route add default dev wg0
case "$ADDRESS" in
  *:*) ip netns exec "$NETNS" ip -6 route add default dev wg0 ;;
esac

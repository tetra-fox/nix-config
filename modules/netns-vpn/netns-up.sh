#!/usr/bin/env bash
set -ex

ip netns add "$NETNS" 2>/dev/null || true
mkdir -p "/etc/netns/$NETNS"
echo 'nameserver 1.1.1.1' > "/etc/netns/$NETNS/resolv.conf"
ip -n "$NETNS" link set lo up

if ! ip link show "$HOST_VETH" >/dev/null 2>&1; then
  ip link add "$HOST_VETH" type veth peer name "$NS_VETH"
  ip link set "$NS_VETH" netns "$NETNS"
  ip addr add "$HOST_VETH_IP/$VETH_CIDR" dev "$HOST_VETH"
  ip link set "$HOST_VETH" up
  ip -n "$NETNS" addr add "$NS_VETH_IP/$VETH_CIDR" dev "$NS_VETH"
  ip -n "$NETNS" link set "$NS_VETH" up
fi

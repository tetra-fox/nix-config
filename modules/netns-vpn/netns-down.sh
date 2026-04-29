#!/usr/bin/env bash
ip link del "$HOST_VETH" 2>/dev/null || true
ip netns del "$NETNS" 2>/dev/null || true

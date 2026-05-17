#!/bin/bash
# Recreate macvlan network for litellm-proxy

# Your macvlan configuration (from docker-compose files)
NETWORK_NAME="macvlan-for-direct-access"
NETWORK_INTERFACE="enp2s0"  # Change if different
NETWORK_SUBNET="192.168.111.0/24"
NETWORK_GATEWAY="192.168.111.254"
NETWORK_IP_RANGE="192.168.111.48/29"

echo "Creating macvlan network: ${NETWORK_NAME}"
echo "Parent interface: ${NETWORK_INTERFACE}"
echo "Subnet: ${NETWORK_SUBNET}"
echo "Gateway: ${NETWORK_GATEWAY}"
echo "IP Range: ${NETWORK_IP_RANGE}"
echo ""

docker network create -d macvlan \
  --subnet="${NETWORK_SUBNET}" \
  --gateway="${NETWORK_GATEWAY}" \
  --ip-range="${NETWORK_IP_RANGE}" \
  -o parent="${NETWORK_INTERFACE}" \
  "${NETWORK_NAME}"

echo ""
echo "Done! Verify with: docker network ls"
echo "Inspect with: docker network inspect ${NETWORK_NAME}"

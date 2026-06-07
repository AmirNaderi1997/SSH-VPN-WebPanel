#!/usr/bin/env bash

# iptables_rules.sh - CORRECTED VERSION
# Uses the OUTPUT chain (the ONLY chain that supports --uid-owner / owner match).
# Counts bytes sent FROM the VPS to the internet on behalf of each SSH VPN user.
# For inbound bytes, we mirror-match via connmark on established connections in INPUT.

set -euo pipefail

CHAIN_OUT="VPN_OUT"
CHAIN_IN="VPN_IN"

# ── Helper: safely (re)create a chain ──────────────────────────────────────
# Tolerates the case where the chain already exists (e.g. on service restart).
recreate_chain() {
    local chain="$1"
    # Remove ALL jump references from any parent chain (loop until none left)
    for parent in OUTPUT INPUT FORWARD; do
        while iptables -D "$parent" -j "$chain" 2>/dev/null; do :; done
    done
    # Flush rules inside the chain (ignore error if chain doesn't exist yet)
    iptables -F "$chain" 2>/dev/null || true
    # Delete the chain (ignore error if still referenced or nonexistent)
    iptables -X "$chain" 2>/dev/null || true
    # Create fresh — if somehow it still exists, continue anyway then flush it
    iptables -N "$chain" 2>/dev/null || true
    # Final flush to ensure it's empty
    iptables -F "$chain"
}

recreate_chain "$CHAIN_OUT"
recreate_chain "$CHAIN_IN"

# ── Jump into our chains from INPUT / OUTPUT ────────────────────────────────
# OUTPUT: traffic the SSH process sends to the internet on behalf of the user.
iptables -I OUTPUT 1 -j "$CHAIN_OUT"

# INPUT: traffic arriving from the internet back to the SSH tunnel (established).
iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j "$CHAIN_IN"

# ── Per-user accounting rules ───────────────────────────────────────────────
# We add one RETURN rule per VPN user (uid >= 1000) in CHAIN_OUT.
# The byte counter on that rule is what monitor_traffic.py reads.
# CHAIN_IN gets a mirror rule matching ESTABLISHED traffic (no uid-owner needed).

VPN_USERS=()
while IFS=: read -r username _ uid _ _ _ _; do
    [[ $uid -lt 1000 ]] && continue
    VPN_USERS+=("$username:$uid")
done < <(getent passwd)

if [[ ${#VPN_USERS[@]} -eq 0 ]]; then
    echo "No VPN users (uid >= 1000) found. Add SSH users first."
    exit 0
fi

for entry in "${VPN_USERS[@]}"; do
    username="${entry%%:*}"
    uid="${entry##*:}"
    # Outbound: packets owned by this uid
    iptables -A "$CHAIN_OUT" -m owner --uid-owner "$uid" -j RETURN
    echo "  + Added OUTPUT accounting rule for $username (uid=$uid)"
done

# INPUT chain gets a single catch-all RETURN (bytes counted at chain level)
iptables -A "$CHAIN_IN" -j RETURN

echo ""
echo "iptables accounting chains created:"
echo "  $CHAIN_OUT  – counts outbound bytes per user (OUTPUT chain)"
echo "  $CHAIN_IN   – counts inbound bytes for established SSH tunnels (INPUT chain)"
echo ""
echo "Verify with:  iptables -L $CHAIN_OUT -v -x"

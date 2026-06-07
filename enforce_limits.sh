#!/usr/bin/env bash

# enforce_limits.sh
# Checks each VPN user's bandwidth usage and expiration date.
# Disables account automatically when limits are exceeded.
# Run daily at 02:00 via cron:
#   0 2 * * * /opt/vpn_manager/enforce_limits.sh >> /var/log/vpn_manager.log 2>&1

set -euo pipefail

DB_HOST="localhost"
DB_USER="vpn_admin"
DB_PASS="vpnadmin123"
DB_NAME="vpn_manager"

echo "=============================="
echo "Enforcement check: $(date)"
echo "=============================="

disable_user() {
    local username="$1"
    local reason="$2"
    echo "[DISABLE] $username — reason: $reason"

    # 1. Lock the Linux account (prevents any new logins)
    usermod -L "$username" 2>/dev/null || echo "  WARN: usermod -L failed for $username"

    # 2. Kill any active SSH sessions for this user immediately
    pkill -u "$username" -KILL 2>/dev/null || true

    # 3. Mark inactive in DB
    mysql -h "$DB_HOST" -u "$DB_USER" "-p${DB_PASS}" "$DB_NAME" \
        -e "UPDATE vpn_users SET active = 0 WHERE username = '${username}';"

    echo "  → $username disabled successfully."
}

# Query: fetch all ACTIVE users and their limits
mapfile -t ROWS < <(
    mysql -h "$DB_HOST" -u "$DB_USER" "-p${DB_PASS}" "$DB_NAME" -N -B \
        -e "SELECT username, used_bytes, bandwidth_limit_gb, expires_at
            FROM vpn_users
            WHERE active = 1;"
)

if [[ ${#ROWS[@]} -eq 0 ]]; then
    echo "No active users found."
    exit 0
fi

NOW_EPOCH=$(date +%s)

for row in "${ROWS[@]}"; do
    IFS=$'\t' read -r username used_bytes bandwidth_limit_gb expires_at <<< "$row"

    # Convert GB limit to bytes
    limit_bytes=$(awk "BEGIN {printf \"%d\", ${bandwidth_limit_gb} * 1073741824}")

    # Convert expires_at to epoch (works on Linux/GNU date)
    expires_epoch=$(date -d "${expires_at}" +%s 2>/dev/null || echo 0)

    DISABLED=0

    # Check bandwidth (0 means unlimited)
    if (( limit_bytes > 0 )) && (( used_bytes >= limit_bytes )); then
        USED_GB=$(awk "BEGIN {printf \"%.2f\", ${used_bytes}/1073741824}")
        disable_user "$username" "bandwidth limit reached (${USED_GB} GB / ${bandwidth_limit_gb} GB)"
        DISABLED=1
    fi

    # Check expiry date (only if not already disabled above)
    if [[ $DISABLED -eq 0 ]] && (( NOW_EPOCH >= expires_epoch )); then
        disable_user "$username" "subscription expired (expired: ${expires_at})"
    fi

done

echo "Enforcement check completed: $(date)"

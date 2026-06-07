#!/usr/bin/env bash
# enforce_single_login.sh
# Enforces a limit of 1 active SSH session per VPN user.
# If a user connects multiple times, the older sessions are terminated,
# allowing the newest connection to succeed without lockouts.

DB_HOST="localhost"
DB_USER="vpn_admin"
DB_PASS="vpnadmin123"
DB_NAME="vpn_manager"

echo "Starting SSH single login enforcement daemon..."

while true; do
    # Get list of all active users from database
    mapfile -t USERS < <(
        mysql -h "$DB_HOST" -u "$DB_USER" "-p${DB_PASS}" "$DB_NAME" -N -B \
            -e "SELECT username FROM vpn_users WHERE active = 1;"
    )

    for username in "${USERS[@]}"; do
        # Find all sshd processes for this user, sorted by start time (oldest first)
        # Note: We filter for processes owned by the user that contain "sshd"
        pids=$(ps -u "$username" -o pid=,comm= --sort=start_time 2>/dev/null | grep -i "sshd" | awk '{print $1}')
        
        # Convert to array
        read -r -a pid_arr <<< "$pids"
        count=${#pid_arr[@]}

        if (( count > 1 )); then
            # Keep the newest PID (which is the last one in the sorted list)
            newest_pid=${pid_arr[-1]}
            
            echo "[$(date)] User '$username' has $count active sessions. Keeping PID $newest_pid, killing older sessions..."
            
            for ((i=0; i<count-1; i++)); do
                pid_to_kill=${pid_arr[i]}
                echo "  → Terminating PID $pid_to_kill"
                kill -9 "$pid_to_kill" 2>/dev/null || true
            done
        fi
    done

    # Run check every 3 seconds
    sleep 3
done

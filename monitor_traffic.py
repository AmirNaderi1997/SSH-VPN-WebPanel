#!/usr/bin/env python3
"""
monitor_traffic.py - CORRECTED VERSION
Reads per-user byte counters from the iptables VPN_OUT chain (OUTPUT),
and total inbound bytes from VPN_IN chain (INPUT), then updates MariaDB.

Run every 5 minutes via cron:
  */5 * * * * /opt/vpn_manager/venv/bin/python /opt/vpn_manager/monitor_traffic.py >> /var/log/vpn_traffic.log 2>&1
"""

import subprocess
import pwd
import sys
from datetime import datetime

import MySQLdb

# ── Config ──────────────────────────────────────────────────────────────────
DB_HOST = "localhost"
DB_USER = "vpn_admin"
DB_PASS = "vpnadmin123"
DB_NAME = "vpn_manager"
CHAIN_OUT = "VPN_OUT"      # per-user outbound counting chain
CHAIN_IN  = "VPN_IN"       # total inbound counting chain

# ── Helpers ─────────────────────────────────────────────────────────────────

def run_iptables(chain: str) -> str:
    result = subprocess.run(
        ["iptables", "-L", chain, "-v", "-x", "-n"],
        capture_output=True, text=True, check=True
    )
    return result.stdout


def parse_out_chain(output: str) -> dict[int, int]:
    """
    Parse VPN_OUT chain output.
    Each line with 'owner UID match <uid>' carries the byte count for that user.
    Returns {uid: bytes}.
    """
    counters: dict[int, int] = {}
    for line in output.splitlines():
        parts = line.split()
        # Expected columns: pkts bytes target prot opt in out source destination [extra]
        if len(parts) < 3:
            continue
        try:
            bytes_cnt = int(parts[1])
        except ValueError:
            continue
        # Look for owner UID match token
        line_lower = line.lower()
        if "uid-owner" in line_lower or "owner uid match" in line_lower:
            # Find the UID value (token after "uid-owner" or after "match")
            for i, tok in enumerate(parts):
                if tok.lower() in ("uid-owner", "match") and i + 1 < len(parts):
                    try:
                        uid = int(parts[i + 1])
                        counters[uid] = counters.get(uid, 0) + bytes_cnt
                    except ValueError:
                        pass
    return counters


def parse_in_chain(output: str) -> int:
    """
    Parse VPN_IN chain output.
    Returns total inbound bytes (sum of all rule byte counters in the chain).
    """
    total = 0
    for line in output.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        try:
            total += int(parts[1])
        except ValueError:
            continue
    return total


def uid_to_username(uid: int) -> str | None:
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return None


def update_db(username: str, new_bytes: int):
    if new_bytes <= 0:
        return
    conn = MySQLdb.connect(host=DB_HOST, user=DB_USER, passwd=DB_PASS, db=DB_NAME)
    cur = conn.cursor()
    cur.execute(
        "UPDATE vpn_users SET used_bytes = used_bytes + %s WHERE username = %s AND active = 1",
        (new_bytes, username)
    )
    conn.commit()
    affected = cur.rowcount
    cur.close()
    conn.close()
    if affected:
        print(f"[{datetime.now()}] Updated {username}: +{new_bytes} bytes")
    else:
        print(f"[{datetime.now()}] WARN: user '{username}' not found or inactive in DB")


def reset_iptables_counters(chain: str):
    """Reset byte/packet counters on a chain after we've read them."""
    subprocess.run(["iptables", "-Z", chain], check=True)


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"[{datetime.now()}] monitor_traffic.py started")

    try:
        out_raw = run_iptables(CHAIN_OUT)
    except subprocess.CalledProcessError as e:
        print(f"ERROR reading {CHAIN_OUT} chain – has iptables_rules.sh been run?\n{e}")
        sys.exit(1)

    counters = parse_out_chain(out_raw)

    if not counters:
        print(f"No per-user counters found in {CHAIN_OUT}. Check iptables_rules.sh output.")
    else:
        for uid, bytes_cnt in counters.items():
            username = uid_to_username(uid)
            if username:
                update_db(username, bytes_cnt)
            else:
                print(f"WARN: UID {uid} has no matching system user")

    # Reset counters so next run only sees NEW bytes (delta counting)
    reset_iptables_counters(CHAIN_OUT)
    reset_iptables_counters(CHAIN_IN)

    print(f"[{datetime.now()}] Done.")


if __name__ == "__main__":
    main()

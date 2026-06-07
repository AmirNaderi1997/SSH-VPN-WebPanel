-- db_init.sql
-- Schema for vpn_users table
CREATE TABLE IF NOT EXISTS vpn_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    bandwidth_limit_gb DECIMAL(10,2) NOT NULL DEFAULT 30,
    time_limit_days INT NOT NULL DEFAULT 30,
    used_bytes BIGINT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Indexes for fast lookup
CREATE INDEX idx_username ON vpn_users(username);
CREATE INDEX idx_active ON vpn_users(active);

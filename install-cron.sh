#!/usr/bin/env bash
set -euo pipefail

CRON_FILE="/etc/cron.d/csss-site"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

cat >"$CRON_FILE" <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Jobs
# Clean expired CAS authentication redirects every 15 minutes
*/15 * * * * csss-site /usr/bin/psql main -c "DELETE FROM auth_redirect WHERE expires_at < NOW();" >/dev/null 2>&1

# Clean expired user sessions at 3AM everyday
0 3 * * * csss-site /usr/bin/psql main -c "DELETE FROM user_session WHERE expires_at < NOW();" >/dev/null 2>&1

# Example future jobs:
# 0 3 * * * csss-site /path/to/some-maintenance-script.sh
# 0 4 * * 0 csss-site /path/to/weekly-cleanup.sh
EOF

chmod 644 "$CRON_FILE"

echo "Installed $CRON_FILE"

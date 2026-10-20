#!/bin/bash
set -euo pipefail

if ! systemctl is-active --quiet nginx; then
    systemctl restart nginx
fi

systemctl is-active --quiet nginx
curl --fail --silent --show-error http://127.0.0.1/ >/dev/null

echo "Nginx is active and the local HTTP health check passed."

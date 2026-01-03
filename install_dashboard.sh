#!/bin/bash

CONFIG_DIR="/config"
DASHBOARD_FILE="$CONFIG_DIR/dashboard.yaml"
CONFIG_FILE="$CONFIG_DIR/configuration.yaml"

echo "▶ Copy dashboard.yaml"
wget -q -O "$DASHBOARD_FILE" \
https://raw.githubusercontent.com/vanhieu2004cv-sketch/ha-dashboard-installer/main/dashboard.yaml

# Kiểm tra xem cấu hình my-dashboard đã tồn tại chưa
if ! grep -q "my-dashboard:" "$CONFIG_FILE"; then
  echo "▶ Add lovelace dashboard config"
  cat <<EOF >> "$CONFIG_FILE"

lovelace:
  dashboards:
    my-dashboard:
      mode: yaml
      title: My Dashboard
      icon: mdi:view-dashboard
      show_in_sidebar: true
      filename: dashboard.yaml
EOF
else
  echo "ℹ Dashboard my-dashboard already exists, skip"
fi

echo "▶ Restart Home Assistant"
ha core restart

echo "✅ DONE: Dashboard installed"

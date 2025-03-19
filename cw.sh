#!/bin/bash

# Variables
CONFIG_DIR="/opt/aws/amazon-cloudwatch-agent/etc"
LOG_CONFIG_FILE="$CONFIG_DIR/log-config.json"
ENV_CONFIG_FILE="$CONFIG_DIR/env-config.json"
AGENT_CONFIG_FILE="$CONFIG_DIR/amazon-cloudwatch-agent.json"
CW_AGENT_SERVICE="amazon-cloudwatch-agent"

# Fetch instance ID dynamically
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Backup existing files
cp "$LOG_CONFIG_FILE" "${LOG_CONFIG_FILE}.bak"
cp "$ENV_CONFIG_FILE" "${ENV_CONFIG_FILE}.bak"
cp "$AGENT_CONFIG_FILE" "${AGENT_CONFIG_FILE}.bak"

# Modify log-config.json
cat << EOF > "$LOG_CONFIG_FILE"
{
    "version": 1,
    "log_configs": [
        {
            "log_group_name": "/apps/dev/crx/core-logs",
            "log_stream_name": "$INSTANCE_ID",
            "file_path": "/apps/dev/crx/logs/core.log*",
            "timezone": "Local"
        },
        {
            "log_group_name": "/apps/dev/crx/access-logs",
            "log_stream_name": "$INSTANCE_ID",
            "file_path": "/apps/dev/crx/logs/access.log*",
            "timezone": "Local"
        },
        {
            "log_group_name": "/apps/dev/crx/data-logs",
            "log_stream_name": "$INSTANCE_ID",
            "file_path": "/apps/dev/crx/logs/data.log*",
            "timezone": "Local"
        }
    ]
}
EOF

# Modify env-config.json
cat << EOF > "$ENV_CONFIG_FILE"
{
    "region": "us-east-1"
}
EOF

# Modify amazon-cloudwatch-agent.json
cat << EOF > "$AGENT_CONFIG_FILE"
{
    "agent": {
        "metrics_collection_interval": 60,
        "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/apps/dev/crx/logs/core.log*",
                        "log_group_name": "/apps/dev/crx/core-logs",
                        "log_stream_name": "$INSTANCE_ID",
                        "timezone": "Local"
                    },
                    {
                        "file_path": "/apps/dev/crx/logs/access.log*",
                        "log_group_name": "/apps/dev/crx/access-logs",
                        "log_stream_name": "$INSTANCE_ID",
                        "timezone": "Local"
                    },
                    {
                        "file_path": "/apps/dev/crx/logs/data.log*",
                        "log_group_name": "/apps/dev/crx/data-logs",
                        "log_stream_name": "$INSTANCE_ID",
                        "timezone": "Local"
                    }
                ]
            }
        }
    }
}
EOF

# Restart CloudWatch Agent
sudo systemctl restart "$CW_AGENT_SERVICE"

# Verify CloudWatch Agent Status
if systemctl is-active --quiet "$CW_AGENT_SERVICE"; then
    echo "✅ CloudWatch Agent restarted successfully."
else
    echo "❌ Failed to restart CloudWatch Agent. Check logs for details."
    journalctl -u "$CW_AGENT_SERVICE" -xe
    exit 1
fi

echo "✅ Configuration updated and applied successfully."

#!/bin/bash
set -euo pipefail
exec > /var/log/dias-setup.log 2>&1

echo "=== DIAS PLATFORM SETUP ==="
echo "Client: ${client_name} | Tier: ${tier} | Domain: ${domain}"
echo "Started: $(date)"

# ── 1. Sistema ──────────────────────────────────────────────────────────────
apt-get update -y && apt-get upgrade -y
apt-get install -y \
  curl wget git unzip \
  ca-certificates gnupg lsb-release \
  fail2ban ufw \
  awscli

# ── 2. Docker ────────────────────────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

# ── 3. Usuário da aplicação ──────────────────────────────────────────────────
useradd -m -s /bin/bash diasapp 2>/dev/null || true
usermod -aG docker diasapp

# ── 4. Diretório do projeto ──────────────────────────────────────────────────
mkdir -p /opt/dias/${client_name}/{data,logs,configs}
chown -R diasapp:diasapp /opt/dias/${client_name}

# ── 5. Login ECR ─────────────────────────────────────────────────────────────
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin \
    "$${AWS_ACCOUNT_ID}.dkr.ecr.${aws_region}.amazonaws.com"

# ── 6. Firewall ──────────────────────────────────────────────────────────────
ufw --force enable
ufw allow 22/tcp    # SSH (restrito via security group)
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw default deny incoming
ufw default allow outgoing

# ── 7. Fail2ban ──────────────────────────────────────────────────────────────
systemctl enable fail2ban
systemctl start fail2ban

# ── 8. Swap (bronze usa t3.small — swap ajuda na memória) ─────────────────
%{ if tier == "bronze" }
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
%{ endif }

# ── 9. Script de backup diário ───────────────────────────────────────────────
cat > /opt/dias/backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BUCKET="dias-backup-${client_name}"
SRC="/opt/dias/${client_name}/data"

[ ! -d "$SRC" ] && exit 0

tar czf "/tmp/backup_$${DATE}.tar.gz" "$SRC"
aws s3 cp "/tmp/backup_$${DATE}.tar.gz" "s3://$${BUCKET}/backups/backup_$${DATE}.tar.gz" \
  --region ${aws_region}
rm -f "/tmp/backup_$${DATE}.tar.gz"
BACKUP_SCRIPT

chmod +x /opt/dias/backup.sh
echo "0 3 * * * diasapp /opt/dias/backup.sh >> /opt/dias/logs/backup.log 2>&1" \
  > /etc/cron.d/dias-backup

# ── 10. CloudWatch Agent ──────────────────────────────────────────────────────
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CW_CONFIG'
{
  "agent": { "run_as_user": "root" },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/dias/${client_name}",
            "log_stream_name": "syslog"
          },
          {
            "file_path": "/opt/dias/logs/*.log",
            "log_group_name": "/dias/${client_name}",
            "log_stream_name": "app"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"] },
      "cpu":  { "measurement": ["cpu_usage_active"], "totalcpu": true }
    },
    "append_dimensions": {
      "Client": "${client_name}",
      "Tier":   "${tier}"
    }
  }
}
CW_CONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# ── 11. Sinal de conclusão ────────────────────────────────────────────────────
echo "SETUP COMPLETE: $(date)" >> /var/log/dias-setup.log
echo "Aguardando deploy do docker-compose via CI/CD ou manualmente."
echo "  scp infra/docker-compose.${tier}.yml diasapp@$(hostname -I | awk '{print $1}'):/opt/dias/${client_name}/docker-compose.yml"
echo "  ssh diasapp@IP 'cd /opt/dias/${client_name} && docker compose up -d'"

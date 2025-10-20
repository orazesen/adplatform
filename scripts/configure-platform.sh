#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}║         Platform Configuration Wizard                      ║${NC}"
echo -e "${BLUE}║                                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if config exists
if [[ -f "platform-config.yaml" ]]; then
    echo -e "${YELLOW}⚠️  platform-config.yaml already exists!${NC}"
    read -p "Overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
fi

# Copy example
cp platform-config.example.yaml platform-config.yaml

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 1: Basic Configuration${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Domain
read -p "Enter your domain (e.g., example.com): " domain
sed -i.bak "s/domain: example.com/domain: $domain/" platform-config.yaml

# Email
read -p "Enter admin email: " email
sed -i.bak "s/admin@example.com/$email/g" platform-config.yaml

# Environment
read -p "Environment (production/staging/development) [production]: " env
env=${env:-production}
sed -i.bak "s/environment: production/environment: $env/" platform-config.yaml

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 2: GitLab Configuration${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# GitLab admin password
while true; do
    read -s -p "GitLab admin password (min 8 chars): " gitlab_pass
    echo ""
    read -s -p "Confirm password: " gitlab_pass2
    echo ""
    if [[ "$gitlab_pass" == "$gitlab_pass2" && ${#gitlab_pass} -ge 8 ]]; then
        sed -i.bak "s/password: CHANGE_ME_STRONG_PASSWORD/password: $gitlab_pass/" platform-config.yaml
        break
    else
        echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
    fi
done

# SMTP
read -p "Configure email (SMTP)? (y/N): " setup_smtp
if [[ "$setup_smtp" =~ ^[Yy]$ ]]; then
    read -p "SMTP server (e.g., smtp.gmail.com): " smtp_server
    read -p "SMTP port [587]: " smtp_port
    smtp_port=${smtp_port:-587}
    read -p "SMTP username: " smtp_user
    read -s -p "SMTP password: " smtp_pass
    echo ""
    
    sed -i.bak "s/address: smtp.gmail.com/address: $smtp_server/" platform-config.yaml
    sed -i.bak "s/port: 587/port: $smtp_port/" platform-config.yaml
    sed -i.bak "s/user: your-email@gmail.com/user: $smtp_user/" platform-config.yaml
    sed -i.bak "s/password: CHANGE_ME/password: $smtp_pass/g" platform-config.yaml
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 3: Monitoring (Grafana)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Grafana password
while true; do
    read -s -p "Grafana admin password (min 8 chars): " grafana_pass
    echo ""
    read -s -p "Confirm password: " grafana_pass2
    echo ""
    if [[ "$grafana_pass" == "$grafana_pass2" && ${#grafana_pass} -ge 8 ]]; then
        # Find and replace the first CHANGE_ME after grafana section
        sed -i.bak "/grafana:/,/admin_password:/ s/admin_password: CHANGE_ME/admin_password: $grafana_pass/" platform-config.yaml
        break
    else
        echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
    fi
done

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 4: Data Engineering (Airflow)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "Setup Airflow? (Y/n): " setup_airflow
if [[ ! "$setup_airflow" =~ ^[Nn]$ ]]; then
    while true; do
        read -s -p "Airflow admin password (min 8 chars): " airflow_pass
        echo ""
        read -s -p "Confirm password: " airflow_pass2
        echo ""
        if [[ "$airflow_pass" == "$airflow_pass2" && ${#airflow_pass} -ge 8 ]]; then
            sed -i.bak "/airflow:/,/password:/ s/password: CHANGE_ME/password: $airflow_pass/" platform-config.yaml
            break
        else
            echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
        fi
    done
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 5: ML Platform (JupyterHub, MLflow)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "Setup ML Platform? (Y/n): " setup_ml
if [[ ! "$setup_ml" =~ ^[Nn]$ ]]; then
    while true; do
        read -s -p "JupyterHub admin password (min 8 chars): " jupyter_pass
        echo ""
        read -s -p "Confirm password: " jupyter_pass2
        echo ""
        if [[ "$jupyter_pass" == "$jupyter_pass2" && ${#jupyter_pass} -ge 8 ]]; then
            sed -i.bak "/jupyterhub:/,/password:/ s/password: CHANGE_ME/password: $jupyter_pass/" platform-config.yaml
            break
        else
            echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
        fi
    done
    
    while true; do
        read -s -p "Kubeflow admin password (min 8 chars): " kubeflow_pass
        echo ""
        read -s -p "Confirm password: " kubeflow_pass2
        echo ""
        if [[ "$kubeflow_pass" == "$kubeflow_pass2" && ${#kubeflow_pass} -ge 8 ]]; then
            sed -i.bak "/kubeflow:/,/password:/ s/password: CHANGE_ME/password: $kubeflow_pass/" platform-config.yaml
            break
        else
            echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
        fi
    done
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 6: Databases${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# PostgreSQL
while true; do
    read -s -p "PostgreSQL admin password (min 8 chars): " pg_pass
    echo ""
    read -s -p "Confirm password: " pg_pass2
    echo ""
    if [[ "$pg_pass" == "$pg_pass2" && ${#pg_pass} -ge 8 ]]; then
        sed -i.bak "/postgresql:/,/admin_password:/ s/admin_password: CHANGE_ME/admin_password: $pg_pass/" platform-config.yaml
        break
    else
        echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
    fi
done

# ClickHouse
while true; do
    read -s -p "ClickHouse admin password (min 8 chars): " ch_pass
    echo ""
    read -s -p "Confirm password: " ch_pass2
    echo ""
    if [[ "$ch_pass" == "$ch_pass2" && ${#ch_pass} -ge 8 ]]; then
        sed -i.bak "/clickhouse:/,/admin_password:/ s/admin_password: CHANGE_ME/admin_password: $ch_pass/" platform-config.yaml
        break
    else
        echo -e "${RED}Passwords don't match or too short. Try again.${NC}"
    fi
done

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 7: Object Storage (MinIO)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

while true; do
    read -s -p "MinIO secret key (min 16 chars): " minio_secret
    echo ""
    read -s -p "Confirm secret key: " minio_secret2
    echo ""
    if [[ "$minio_secret" == "$minio_secret2" && ${#minio_secret} -ge 16 ]]; then
        sed -i.bak "/minio:/,/secret_key:/ s/secret_key: CHANGE_ME_STRONG_SECRET/secret_key: $minio_secret/" platform-config.yaml
        break
    else
        echo -e "${RED}Keys don't match or too short (min 16 chars). Try again.${NC}"
    fi
done

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Step 8: SSL/TLS Configuration${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "Use Let's Encrypt for SSL? (Y/n): " use_letsencrypt
if [[ "$use_letsencrypt" =~ ^[Nn]$ ]]; then
    sed -i.bak "s/provider: letsencrypt/provider: self-signed/" platform-config.yaml
    echo -e "${YELLOW}⚠️  Self-signed certificates will be used. Not recommended for production!${NC}"
else
    read -p "Use Let's Encrypt staging (for testing)? (y/N): " le_staging
    if [[ "$le_staging" =~ ^[Yy]$ ]]; then
        sed -i.bak "s/staging: false/staging: true/" platform-config.yaml
    fi
fi

# Clean up backup files
rm -f platform-config.yaml.bak

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Configuration Summary${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo "Domain:           $domain"
echo "Admin Email:      $email"
echo "Environment:      $env"
echo "GitLab:           https://gitlab.$domain"
echo "Grafana:          https://grafana.$domain"
echo "Airflow:          https://airflow.$domain"
echo "JupyterHub:       https://jupyter.$domain"
echo "MLflow:           https://mlflow.$domain"
echo "Vault:            https://vault.$domain"

echo -e "\n${GREEN}✅ Configuration saved to platform-config.yaml${NC}"
echo -e "${YELLOW}⚠️  Review the file and adjust advanced settings if needed${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review: ${GREEN}vim platform-config.yaml${NC}"
echo -e "  2. Deploy: ${GREEN}make deploy-platform ENV=$env${NC}"
echo ""

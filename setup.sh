#!/usr/bin/env bash

# Pretty colors for a fun experience!
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34k'
YELLOW='\033[1;33m'
NC='\033[0m'

# Cat banner
echo -e "${BLUE}"
cat << "EOF"
 /\___/\
(  o o  )
(  =^=  ) 
 (--m-m-)    Boundary Setup Time!
EOF
echo -e "${NC}"

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script as root or with sudo${NC}"
  exit 1
fi

# Check RHEL/CentOS version
if [ ! -f /etc/redhat-release ]; then
    echo -e "${RED}This script requires RHEL or CentOS!${NC}"
    exit 1
fi

# Extract version number
os_version=$(cat /etc/redhat-release | grep -oE '[0-9]+\.' | cut -d'.' -f1)
if [ "$os_version" -lt 8 ]; then
    echo -e "${RED}This script requires RHEL/CentOS 8 or higher${NC}"
    exit 1
fi

# Check and install required packages
echo -e "${BLUE}Checking required packages...${NC}"

required_packages=(
    "ansible-core"
    "python3"
    "python3-pip"
    "yum-utils"
    "policycoreutils-python-utils"
    "firewalld"
    "openssl"
    "curl"
)

# Add this helper function at the beginning
progress_check() {
    echo -e "\n${GREEN}✓${NC} $1 completed"
}

# Function to check if a package is installed
is_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

# Check and install missing packages
missing_packages=()
for package in "${required_packages[@]}"; do
    if ! is_installed "$package"; then
        missing_packages+=("$package")
    fi
done

if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "${YELLOW}Installing missing packages: ${missing_packages[*]}${NC}"
    dnf install -y "${missing_packages[@]}"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install required packages. Please check your network connection and try again.${NC}"
        exit 1
    fi
fi

# Check if ansible-vault is available after package installation
if ! command -v ansible-vault &> /dev/null; then
    echo -e "${RED}ansible-vault command not found even after package installation.${NC}"
    echo -e "${RED}Please ensure ansible is properly installed.${NC}"
    exit 1
fi

# Check if firewalld is running
if ! systemctl is-active --quiet firewalld; then
    echo -e "${YELLOW}Enabling and starting firewalld...${NC}"
    systemctl enable --now firewalld
fi

# Check SELinux status
if [ "$(getenforce)" == "Disabled" ]; then
    echo -e "${YELLOW}Warning: SELinux is disabled. It's recommended to run with SELinux enabled in enforcing mode.${NC}"
fi

# Verify Python3 is the default python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 is required but not found${NC}"
    exit 1
fi

# Check directory structure
if [[ ! -d "./playbooks" || ! -d "./inventory" || ! -d "./group_vars" ]]; then
    echo -e "${RED}⚠️  Oops! Please run this script from the root of the repository!${NC}"
    echo -e "${RED}Expected to find playbooks/, inventory/, and group_vars/ directories${NC}"
    exit 1
fi

echo -e "${GREEN}All system requirements met! 🎉${NC}"
echo -e "Moving on to Boundary configuration...\n"

# Standardized prompt function
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    echo -e "${YELLOW}${prompt}${NC} [${default}]: "
    read -r response
    echo "${response:-$default}"
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate file exists
validate_file() {
    if [[ ! -f "$1" ]]; then
        echo -e "${RED}File not found: $1${NC}"
        return 1
    fi
    return 0
}

# Prerequisites checklist
echo -e "${GREEN}=== Prerequisites Checklist ===${NC}"
echo -e "Before we begin, please ensure you have:"
echo -e "✅ A PostgreSQL database ready"
echo -e "✅ Vault server configured with Transit engine"
echo -e "✅ Load balancer provisioned"
echo -e "✅ Network connectivity between components"
echo -e "✅ SSL certificates for TLS"
echo -e "\nPress ENTER when ready to continue..."
read

# Organization Details
echo -e "\n${BLUE}==== Organization Details =====${NC}"
echo -e "Please input the Boundary's organization name"
org_name=$(prompt_with_default "Organization name" "Awesome Corp")

# Load Balancer Setup
echo -e "\n${BLUE}==== Load Balancer Setup =====${NC}"
echo -e "The load balancer will distribute traffic to your controllers"
echo -e "Required ports:"
echo -e "  - 9200 (API)"
echo -e "  - 9201 (Cluster)"
echo -e "  - 9203 (Ops)"
lb_addr=$(prompt_with_default "Load balancer DNS/IP address" "boundary.example.com")

# TLS Configuration
echo -e "\n${BLUE}==== TLS Configuration =====${NC}"
while true; do
    ssl_cert_path=$(prompt_with_default "Path to SSL certificate" "/etc/boundary.d/tls/boundary-cert.pem")
    ssl_key_path=$(prompt_with_default "Path to SSL private key" "/etc/boundary.d/tls/boundary-key.pem")
    
    if validate_file "$ssl_cert_path" && validate_file "$ssl_key_path"; then
        break
    else
        echo -e "${YELLOW}Please ensure both certificate and key files exist.${NC}"
    fi
done

# Database Configuration
echo -e "\n${BLUE}==== Database Configuration =====${NC}"
echo -e "Let's configure your PostgreSQL connection:\n"
db_host=$(prompt_with_default "Database hostname" "boundary-db.example.com")
db_port=$(prompt_with_default "Database port" "5432")
db_name=$(prompt_with_default "Database name" "boundary")
db_user=$(prompt_with_default "Database username" "boundary")
echo -e "${YELLOW}Database password${NC} (will be encrypted): "
read -s db_password
echo

# Vault Configuration
echo -e "\n${BLUE}==== Vault Configuration =====${NC}"
echo -e "Vault is used for KMS encryption - ensure Transit engine is enabled\n"
vault_addr=$(prompt_with_default "Vault server URL" "https://vault.example.com:8200")
vault_path=$(prompt_with_default "Transit secrets engine path" "transit")
echo -e "${YELLOW}Vault token${NC} (will be encrypted): "
read -s vault_token
echo

# Controller Configuration
echo -e "\n${BLUE}==== Controller Configuration =====${NC}"
echo -e "Recommended: 3 controllers for high availability"
while true; do
    controller_count=$(prompt_with_default "Number of controllers" "3")
    if [[ "$controller_count" =~ ^[1-9][0-9]*$ ]]; then
        break
    else
        echo -e "${RED}Please enter a valid number${NC}"
    fi
done

declare -A controller_ips
declare -A controller_users
for ((i=1; i<=controller_count; i++)); do
    echo -e "\n${BLUE}Controller $i Configuration:${NC}"
    while true; do
        ip=$(prompt_with_default "IP address" "")
        if validate_ip "$ip"; then
            controller_ips["controller-$i"]=$ip
            break
        else
            echo -e "${RED}Invalid IP address format. Please try again.${NC}"
        fi
    done
    user=$(prompt_with_default "SSH user" "ec2-user")
    controller_users["controller-$i"]=$user
done

# Worker Configuration
echo -e "\n${BLUE}==== Worker Configuration =====${NC}"
echo -e "Ingress workers: Accept initial connections (DMZ)"
echo -e "Egress workers: Connect to final targets (private network)\n"

# Ingress Workers
while true; do
    ingress_count=$(prompt_with_default "Number of ingress workers" "2")
    if [[ "$ingress_count" =~ ^[1-9][0-9]*$ ]]; then
        break
    else
        echo -e "${RED}Please enter a valid number${NC}"
    fi
done

declare -A ingress_ips
declare -A ingress_users
for ((i=1; i<=ingress_count; i++)); do
    echo -e "\n${BLUE}Ingress Worker $i Configuration:${NC}"
    while true; do
        ip=$(prompt_with_default "IP address" "")
        if validate_ip "$ip"; then
            ingress_ips["ingress-worker-$i"]=$ip
            break
        else
            echo -e "${RED}Invalid IP address format. Please try again.${NC}"
        fi
    done
    user=$(prompt_with_default "SSH user" "ec2-user")
    ingress_users["ingress-worker-$i"]=$user
done

# Egress Workers
while true; do
    egress_count=$(prompt_with_default "Number of egress workers" "2")
    if [[ "$egress_count" =~ ^[1-9][0-9]*$ ]]; then
        break
    else
        echo -e "${RED}Please enter a valid number${NC}"
    fi
done

declare -A egress_ips
declare -A egress_users
for ((i=1; i<=egress_count; i++)); do
    echo -e "\n${BLUE}Egress Worker $i Configuration:${NC}"
    while true; do
        ip=$(prompt_with_default "IP address" "")
        if validate_ip "$ip"; then
            egress_ips["egress-worker-$i"]=$ip
            break
        else
            echo -e "${RED}Invalid IP address format. Please try again.${NC}"
        fi
    done
    user=$(prompt_with_default "SSH user" "ec2-user")
    egress_users["egress-worker-$i"]=$user
done

# Review Configuration
echo -e "\n${GREEN}==== Configuration Summary =====${NC}"
echo -e "Organization: ${org_name}"
echo -e "Load Balancer: ${lb_addr}"
echo -e "Database Connection: ${db_host}:${db_port}/${db_name}"
echo -e "Vault Server: ${vault_addr}"
echo -e "TLS Certificate: ${ssl_cert_path}"
echo -e "TLS Key: ${ssl_key_path}"
echo -e "\nController Nodes: ${controller_count}"
for controller in "${!controller_ips[@]}"; do
    echo -e "  - ${controller}: ${controller_ips[$controller]} (${controller_users[$controller]})"
done
echo -e "\nIngress Workers: ${ingress_count}"
for worker in "${!ingress_ips[@]}"; do
    echo -e "  - ${worker}: ${ingress_ips[$worker]} (${ingress_users[$worker]})"
done
echo -e "\nEgress Workers: ${egress_count}"
for worker in "${!egress_ips[@]}"; do
    echo -e "  - ${worker}: ${egress_ips[$worker]} (${egress_users[$worker]})"
done

echo
read -p "Does this look correct? (y/n) " confirm
if [[ $confirm != "y" ]]; then
    echo -e "${RED}Setup cancelled. Please run the script again.${NC}"
    exit 1
fi

# Generate inventory/hosts.yml
echo -e "\n${GREEN}Generating inventory file...${NC}"
cat > inventory/hosts.yml << EOF
---
all:
  children:
    boundary_servers:
      children:
        boundary_controllers:
          hosts:
EOF

# Add controllers
for controller in "${!controller_ips[@]}"; do
    cat >> inventory/hosts.yml << EOF
            ${controller}:
              ansible_host: ${controller_ips[$controller]}
              controller_name: "boundary-${controller}"
              ansible_user: ${controller_users[$controller]}
EOF
done

cat >> inventory/hosts.yml << EOF
          vars:
            boundary_cluster_addr: "${lb_addr}"
            postgresql_host: "${db_host}"
            postgresql_port: "${db_port}"
            postgresql_db: "${db_name}"
            postgresql_user: "${db_user}"
            tls_cert_file: "${ssl_cert_path}"
            tls_key_file: "${ssl_key_path}"

        boundary_workers:
          children:
            ingress_workers:
              hosts:
EOF

# Add ingress workers
for worker in "${!ingress_ips[@]}"; do
    cat >> inventory/hosts.yml << EOF
                ${worker}:
                  ansible_host: ${ingress_ips[$worker]}
                  worker_type: "ingress"
                  ansible_user: ${ingress_users[$worker]}
EOF
done

cat >> inventory/hosts.yml << EOF
              vars:
                worker_additional_tags: ["dmz", "public"]

            egress_workers:
              hosts:
EOF

# Add egress workers
for worker in "${!egress_ips[@]}"; do
    cat >> inventory/hosts.yml << EOF
                ${worker}:
                  ansible_host: ${egress_ips[$worker]}
                  worker_type: "egress"
                  ansible_user: ${egress_users[$worker]}
EOF
done

cat >> inventory/hosts.yml << EOF
              vars:
                worker_additional_tags: ["private", "internal"]

  vars:
    ansible_python_interpreter: /usr/bin/python3
    boundary_controller_addresses: [$(for c in "${!controller_ips[@]}"; do echo -n "\"$c:9201\", "; done | sed 's/, $//')]
    tls_enabled: true
    organization_name: "${org_name}"
    vault_addr: "${vault_addr}"
EOF

# Create encrypted variables
echo -e "\n${GREEN}Creating encrypted variables...${NC}"
echo "# Ansible-vault encrypted variables - $(date)" > group_vars/all.yml
echo "${db_password}" | ansible-vault encrypt_string --name 'db_password' >> group_vars/all.yml
echo "${vault_token}" | ansible-vault encrypt_string --name 'vault_token' >> group_vars/all.yml

# Success!
echo -e "\n${GREEN}==== Setup Complete! =====${NC}"
echo -e "🎉 Your Boundary configuration has been generated!"
echo -e "\nNext steps:"
echo -e "1. Review the generated files:"
echo -e "   - inventory/hosts.yml"
echo -e "   - group_vars/all.yml"
echo -e "\n2. Run the deployment:"
echo -e "   ansible-playbook -i inventory/hosts.yml playbooks/deploy_boundary.yml --ask-vault-pass"
echo -e "\n3. Get ready to rock! 🎸\n"

# End banner
cat << "EOF"
         __      _
        o'')}____//
         `_/      )
         (_(_/-(_/    Setup Complete! 🎸

EOF
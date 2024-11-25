# HashiCorp Boundary Manual Deployment Guide

## Deployment Process Overview 🗺️

### 1. Prerequisites Configuration

#### Infrastructure Requirements
- RHEL/CentOS 8 or higher for all nodes
- PostgreSQL database instance
- Vault server with Transit engine enabled
- Load balancer for controllers
- Network connectivity between all components
- SSL certificates from trusted CA

#### Network Requirements
- Controllers: TCP ports 9200-9203
- Workers: TCP port 9202
- PostgreSQL: TCP port 5432
- Internal network connectivity

### 2. Environment Configuration 🛠️

#### A. Create Boundary System User
```bash
sudo groupadd -r boundary
sudo useradd -r -g boundary -d /etc/boundary.d -s /sbin/nologin boundary
```

#### B. Directory Structure Setup
```bash
sudo mkdir -p /etc/boundary.d/{tls,vault}
sudo mkdir -p /var/log/boundary
sudo mkdir -p /var/lib/boundary/worker
sudo chown -R boundary:boundary /etc/boundary.d /var/log/boundary /var/lib/boundary
sudo chmod 750 /etc/boundary.d /var/log/boundary /var/lib/boundary
```

#### C. TLS Certificate Installation
```bash
sudo cp boundary-cert.pem /etc/boundary.d/tls/
sudo cp boundary-key.pem /etc/boundary.d/tls/
sudo chown boundary:boundary /etc/boundary.d/tls/*
sudo chmod 640 /etc/boundary.d/tls/*
```

### 3. Vault KMS Configuration 🔐

1. Run Terraform for Vault configuration:
```bash
cd terraform/vault
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply
```

2. Save the output tokens for:
   - boundary_controller_token
   - boundary_worker_token

### 4. Configuration Files Setup 📝

#### A. Environment File
Create `/etc/boundary.d/boundary.env`:
```bash
VAULT_TOKEN=<controller_or_worker_token>
POSTGRESQL_CONNECTION_STRING="postgresql://user:pass@host:5432/boundary"
```

#### B. Update Ansible Variables
1. Copy example files:
```bash
cp group_vars/all.yml.example group_vars/all.yml
cp group_vars/boundary_controllers.yml.example group_vars/boundary_controllers.yml
cp group_vars/boundary_workers.yml.example group_vars/boundary_workers.yml
```

2. Edit variables:
   - all.yml: Common settings
   - boundary_controllers.yml: Controller-specific
   - boundary_workers.yml: Worker-specific

#### C. Update Inventory
1. Copy example inventory:
```bash
cp inventory/example.yml inventory/hosts.yml
```

2. Update with your infrastructure details:
   - Controller nodes
   - Worker nodes (ingress/egress)
   - Host variables

### 5. Run Ansible Playbooks 🚀

#### A. Base System Setup
```bash
ansible-playbook -i inventory/hosts.yml playbooks/base_setup.yml
```

#### B. Security Hardening
```bash
ansible-playbook -i inventory/hosts.yml playbooks/security_hardening.yml
```

#### C. Deploy Controllers
```bash
ansible-playbook -i inventory/hosts.yml playbooks/controller_setup.yml
```

#### D. Deploy Workers
```bash
ansible-playbook -i inventory/hosts.yml playbooks/worker_setup.yml
```

### 6. Boundary Configuration 🎮

Run Terraform for Boundary configuration:
```bash
cd terraform/boundary
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply
```

### 7. Verify Deployment ✅

#### A. Check Controller Health
```bash
curl -k https://localhost:9203/health
```

#### B. Verify Worker Connection
```bash
boundary workers list -format json
```

#### C. Test Authentication
```bash
boundary authenticate
```

## Troubleshooting 🔧

### Common Issues

1. Controller won't start
   - Check PostgreSQL connection
   - Verify Vault token permissions
   - Review controller logs: `/var/log/boundary/controller.log`

2. Worker registration fails
   - Verify network connectivity to controllers
   - Check worker authentication token
   - Review worker logs: `/var/log/boundary/worker.log`

3. TLS issues
   - Verify certificate permissions
   - Check certificate validity
   - Ensure proper DNS resolution

### Logs Location
- Controllers: `/var/log/boundary/controller.log`
- Workers: `/var/log/boundary/worker.log`
- System: `journalctl -u boundary`

## Security Notes 🛡️

1. File Permissions
   - Configuration files: 640
   - Directories: 750
   - TLS certificates: 640

2. SELinux Configuration
   - Keep enabled in enforcing mode
   - Configure proper contexts for Boundary directories

3. Firewall Rules
   - Only open required ports
   - Use separate security groups per role
   - Implement proper network segmentation

## Maintenance 🔧

### Backup Procedures
1. PostgreSQL database backup
2. Configuration files backup
3. TLS certificates backup
4. Worker authentication tokens backup

### Updates
1. Update packages: `sudo dnf update boundary-enterprise`
2. Rolling updates for controllers
3. Worker updates after controllers
4. Verify health after each update
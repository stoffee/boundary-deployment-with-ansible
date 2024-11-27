# Single Node Boundary Deployment 🎯

A simplified deployment for development and testing that runs both controller and worker on a single node with a local PostgreSQL database.

## Prerequisites

- You've already followed the main README.md setup steps
- RHEL/CentOS environment is ready
- Ansible is installed and working

## Quick Deploy

1. From the root of the repository, run:
```bash
sudo ansible-playbook playbooks/boundary_deploy_single_node.yml
```

2. Save your initialization data:
```bash
sudo cat /etc/boundary.d/init-output.txt
```
⚠️ Keep this information safe - you'll need these keys for administration!

## What Gets Deployed

- PostgreSQL 14 database
- Boundary controller + worker on the same node
- Basic firewall rules (ports 9200-9202)
- SELinux configurations
- Systemd services

## Verify It Worked

1. Check services:
```bash
sudo systemctl status boundary
sudo systemctl status postgresql-14
```

2. Test the API:
```bash
curl http://localhost:9200/v1/health
```

3. Access the UI:
```bash
http://<your-server-ip>:9200
```

## Troubleshooting

- Logs are in `/var/log/boundary/`
- PostgreSQL logs in `/var/lib/pgsql/14/data/log/`
- Use `journalctl -u boundary` for service logs

## Notes

- This is for development/testing only! 
- TLS is disabled by default
- Using local KMS (AEAD) for simplicity
- All services run as proper system users
- SELinux remains enforcing (as it should!)

Need the full production setup? Check out our main deployment guides in README.md! 🚀
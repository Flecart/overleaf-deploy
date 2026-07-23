# Overleaf Mentor AWS migration

This repository provisions the replacement for the live service at
`overleaf.safe.eu` in AWS account `906513713427`. It mirrors the
private `jiarui-liu/overleaf` development stack rather than deploying stock
Overleaf Toolkit images.

## Architecture

- Ubuntu 24.04, `t3.large`, in `us-east-1`
- 40 GiB encrypted, disposable root disk
- 120 GiB encrypted, deletion-protected data disk
- Docker, containerd build data, and `/home/ubuntu` stored on the persistent disk
- Caddy on ports 80/443, forwarding to the webpack service on port 8080
- SSM instance access plus public IPv4 SSH authenticated by the operator key
- Versioned and encrypted S3 Terraform state

Terraform intentionally does not manage application credentials. The migration
copies `/home/ubuntu/overleaf/.env_credentials` directly between machines with
mode `0600`, so credentials never enter state or cloud-init logs.

## Provisioning

Authenticate the `default` AWS CLI profile to account `906513713427`, then:

```bash
AWS_PROFILE=default scripts/bootstrap_state.sh
cp terraform.tfvars.example terraform.tfvars
terraform init
scripts/terraform_via_aws_login.sh plan -out=overleaf.tfplan
scripts/terraform_via_aws_login.sh apply overleaf.tfplan
```

Wait for `/var/lib/cloud/overleaf-bootstrap-complete` on the destination before
migrating. Terraform creates a new key pair from the public key configured by
`ssh_public_key_path`; it does not use or alter the unrelated `overleaf-key`.

The data volume has `prevent_destroy = true`. A normal `terraform destroy` will
therefore fail until an operator intentionally removes that protection.

## Migration runbook

Set the destination Elastic IP from `terraform output -raw public_ip`:

```bash
export TARGET_IP=203.0.113.20
scripts/migrate_overleaf.sh preflight
scripts/migrate_overleaf.sh sync-workspace
scripts/migrate_overleaf.sh build
scripts/migrate_overleaf.sh start-http-test
```

At this point the disposable, empty-data test service is available at
`http://<TARGET_IP>`. Create only a fake account. When testing is complete,
stop it and pre-seed the non-database volumes:

```bash
scripts/migrate_overleaf.sh stop-http-test
scripts/migrate_overleaf.sh sync-data-online
```

The online seed deliberately excludes MongoDB and Redis. Their files are only
copied by `final-sync` after both stacks are stopped; the fake test account is
therefore discarded during the final migration.

The workspace sync excludes machine credentials and caches (`.ssh`, `.aws`,
GPG/Docker credentials, histories, `.cache`, and Cursor server state). It keeps
repositories, datasets, annotations, and Overleaf's dedicated credentials.

The private fork currently has a committed `package.json`/`package-lock.json`
mismatch for `esbuild`. The build command regenerates only `package-lock.json`
with the Dockerfile's Node 24.13.0 toolchain, verifies no other source files
changed, and saves the original lockfile outside the repository.

`start-http-test` and `final-sync` set `OVERLEAF_SITE_URL` in the copied
development environment to `https://<service_hostname>`. This intentional
runtime hostname change and the repaired lockfile are the only expected source
tree differences on the destination.

At least one current DNS TTL (approximately two hours) before cutover, ask the
Toronto DNS administrator to lower the A-record TTL to 60 seconds. During the
agreed write freeze:

```bash
scripts/migrate_overleaf.sh final-sync
scripts/migrate_overleaf.sh validate
scripts/migrate_overleaf.sh proxy-source
```

After `proxy-source`, stale DNS clients hitting the old HTTPS endpoint are sent
to the new machine, while the old application containers remain stopped. The
DNS administrator can then set:

```text
overleaf.safe.eu. 60 IN A <TARGET_IP>
```

Once public DNS resolves to the destination, enable its production TLS site:

```bash
scripts/migrate_overleaf.sh enable-target-tls
```

Validate HTTPS, login, an existing project, project history, upload/download,
LaTeX compilation, and AI-tutor behavior. Then create an encrypted snapshot of
the destination data volume.

## Rollback

Before users write data to the replacement, restore the old proxy and stack:

```bash
scripts/migrate_overleaf.sh rollback-proxy
```

If users have already written to the replacement, do not run the simple
rollback: first put both systems in maintenance mode and reverse-migrate the
new MongoDB and volume data to avoid losing those writes.

The approved operating choice leaves the old EC2 instance running as a proxy
and rollback point, so its original AWS account continues to incur charges.

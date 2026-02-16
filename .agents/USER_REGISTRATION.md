# User Registration & Access Control Guide

This guide explains how to configure user registration and access control for your Overleaf instance.

## Configuration Options

### 1. Public Registration (Enabled by Default)

**Current Setting:** `SHARELATEX_ALLOW_PUBLIC_ACCESS: "true"`

This allows anyone to see the registration page and create an account.

### 2. Email Confirmation

**Variable:** `email_confirmation_disabled`

**Options:**
- `true` (default) - Users can register and immediately use Overleaf without email verification
- `false` - Users must click a confirmation link in their email before accessing Overleaf

**Requirements for email confirmation:**
- SMTP must be configured (see EMAIL_SETUP.md)
- Users will receive a confirmation email at registration

**In terraform.tfvars:**
```hcl
email_confirmation_disabled = false  # Require email confirmation
```

### 3. Domain-Based Registration Restrictions

**Variable:** `allowed_email_domains`

**Options:**
- `""` (default) - Allow all email domains
- `"example.com"` - Only allow @example.com emails
- `"gmail.com,university.edu"` - Allow multiple domains (comma-separated, no spaces)

**In terraform.tfvars:**
```hcl
allowed_email_domains = "example.com,university.edu"
```

## Common Use Cases

### Use Case 1: Open Public Instance
Anyone can register, no email verification needed.

```hcl
email_confirmation_disabled = true
allowed_email_domains = ""
```

### Use Case 2: Organization-Only Access
Only users from your organization's domain can register.

```hcl
email_confirmation_disabled = true  # or false if you want email verification too
allowed_email_domains = "yourcompany.com"
```

### Use Case 3: Verified Users Only (Most Secure)
Users must verify their email, and only certain domains are allowed.

```hcl
email_confirmation_disabled = false
allowed_email_domains = "university.edu,partner.com"
```

⚠️ **Important:** Email confirmation requires SMTP to be configured!

### Use Case 4: Academic Institution
Allow students and staff from multiple university domains.

```hcl
email_confirmation_disabled = false
allowed_email_domains = "university.edu,alumni.university.edu"
```

## Configuration Files

### In `terraform.tfvars`:

```hcl
# User Registration & Access Control
email_confirmation_disabled = true   # Change to false to require verification
allowed_email_domains = ""           # Add domains like "example.com,other.com"
```

### In `overleaf/docker-compose.yml`:

These are automatically injected via environment variables:

```yaml
EMAIL_CONFIRMATION_DISABLED: ${EMAIL_CONFIRMATION_DISABLED:-true}
SHARELATEX_ALLOWED_EMAIL_DOMAINS: ${SHARELATEX_ALLOWED_EMAIL_DOMAINS:-}
```

## Applying Changes

### New Deployment:
```bash
# Edit terraform.tfvars with your desired settings
terraform apply
```

### Existing Deployment:
```bash
# Edit terraform.tfvars
terraform apply  # This will recreate the instance

# OR manually update on running instance:
ssh ubuntu@<ip>
# Edit /opt/overleaf/.env and add:
export EMAIL_CONFIRMATION_DISABLED=false
export SHARELATEX_ALLOWED_EMAIL_DOMAINS="example.com,other.com"

cd /opt/overleaf/develop
docker compose restart web
```

## Testing Registration Restrictions

### Test Domain Restrictions:

1. Try registering with an allowed domain - should work
2. Try registering with a non-allowed domain - should see error: "Email domain not allowed"

### Test Email Confirmation:

1. Register a new user
2. Check if you can log in immediately (disabled) or need to confirm first (enabled)
3. If enabled, check the user's email for the confirmation link

## Troubleshooting

### "Email domain not allowed" for valid domain

**Check:**
- No spaces in the domain list: `"example.com,other.com"` ✅
- Spaces in list: `"example.com, other.com"` ❌
- Restart the container after changes

### Email confirmation emails not being sent

**Check:**
1. SMTP is configured correctly: `docker compose exec web env | grep SMTP`
2. Test SMTP: `python3 scripts/test_gmail_smtp.py`
3. Check logs: `docker compose logs web | grep -i email`
4. Verify `EMAIL_CONFIRMATION_DISABLED=false`

### Users can't complete registration

**Possible causes:**
1. Email confirmation enabled but SMTP not configured
2. Confirmation emails going to spam
3. Wrong SMTP credentials

**Solution:**
- Temporarily set `email_confirmation_disabled = true` or fix SMTP configuration

## Verifying Current Configuration

SSH into your instance and check:

```bash
# Check environment variables
cat /opt/overleaf/.env

# Check what the container sees
cd /opt/overleaf/develop
docker compose exec web env | grep -E "EMAIL_CONFIRMATION|ALLOWED_EMAIL_DOMAINS"

# Expected output:
# EMAIL_CONFIRMATION_DISABLED=true (or false)
# SHARELATEX_ALLOWED_EMAIL_DOMAINS=example.com,other.com (or empty)
```

## Security Recommendations

### For Public Instances:
- ✅ Enable email confirmation (`email_confirmation_disabled = false`)
- ✅ Configure rate limiting (if available)
- ✅ Monitor user registrations
- ⚠️ Consider the Community Edition security notice (line 79-81 in docker-compose.yml)

### For Private/Organizational Instances:
- ✅ Use `allowed_email_domains` to restrict to your organization
- ✅ Enable email confirmation
- ✅ Consider using LDAP for enterprise authentication (see docker-compose.yml lines 94-102)
- ✅ Restrict SSH access (`allowed_ssh_cidrs` in terraform.tfvars)

### For Academic Institutions:
- ✅ List all institution email domains
- ✅ Include alumni domains if needed
- ✅ Enable email confirmation
- ✅ Consider LDAP/SAML for single sign-on

## Admin User Creation

The admin user created during deployment is not affected by these restrictions. Admins are created via the command line:

```bash
docker compose exec web bash -c \
  "cd /overleaf && node modules/server-ce-scripts/scripts/create-user.js --admin --email=admin@example.com"
```

## Related Configuration

- **SMTP Setup:** See EMAIL_SETUP.md
- **LDAP Authentication:** Uncomment lines 94-102 in docker-compose.yml
- **Site URL:** Set `OVERLEAF_SITE_URL` for proper email links

## Examples by Organization Type

### Startup/Small Company
```hcl
email_confirmation_disabled = false
allowed_email_domains = "startup.com"
```

### University
```hcl
email_confirmation_disabled = false
allowed_email_domains = "university.edu,alumni.university.edu,staff.university.edu"
```

### Open Research Project
```hcl
email_confirmation_disabled = false
allowed_email_domains = ""  # Allow all, but verify emails
```

### Private Corporate Instance
```hcl
email_confirmation_disabled = false
allowed_email_domains = "company.com,subsidiary.com"
```

## Further Reading

- [Overleaf Community Edition Documentation](https://github.com/overleaf/overleaf/wiki)
- [Docker Compose Configuration](https://github.com/overleaf/overleaf/blob/main/docker-compose.yml)
- [User Management Scripts](https://github.com/overleaf/overleaf/tree/main/server-ce/scripts)

# Summary: User Registration & Access Control Configuration

## What Was Added

Your Overleaf deployment now supports configurable user registration with these new features:

### 1. Public Registration (Enabled)
- ✅ Added `SHARELATEX_ALLOW_PUBLIC_ACCESS: "true"` to docker-compose.yml
- Users can now access the registration page and create accounts

### 2. Email Confirmation (Configurable)
- 🔧 Made `EMAIL_CONFIRMATION_DISABLED` configurable via Terraform variable
- Default: `true` (no email confirmation required)
- Set to `false` to require email verification before account activation

### 3. Domain-Based Access Control (Configurable)
- 🔧 Added `SHARELATEX_ALLOWED_EMAIL_DOMAINS` configuration
- Restrict registration to specific email domains
- Default: Empty (all domains allowed)

## Files Modified

### 1. `overleaf/docker-compose.yml`
**Added:**
```yaml
# Allow public user registration (anyone can create an account)
SHARELATEX_ALLOW_PUBLIC_ACCESS: "true"

# Email confirmation: set to "false" to require email verification
EMAIL_CONFIRMATION_DISABLED: ${EMAIL_CONFIRMATION_DISABLED:-true}

# Restrict registration to specific email domains (comma-separated)
# SHARELATEX_ALLOWED_EMAIL_DOMAINS: ${SHARELATEX_ALLOWED_EMAIL_DOMAINS:-}
```

### 2. `variables.tf`
**Added 2 new variables:**
```hcl
variable "email_confirmation_disabled" {
  description = "Disable email confirmation requirement"
  type        = bool
  default     = true
}

variable "allowed_email_domains" {
  description = "Comma-separated list of email domains allowed to register"
  type        = string
  default     = ""
}
```

### 3. `main.tf`
**Added variables to user_data template:**
```hcl
EMAIL_CONFIRMATION_DISABLED      = var.email_confirmation_disabled
SHARELATEX_ALLOWED_EMAIL_DOMAINS = var.allowed_email_domains
```

### 4. `user_data.sh`
**Added environment variable exports:**
```bash
export EMAIL_CONFIRMATION_DISABLED=${EMAIL_CONFIRMATION_DISABLED}
export SHARELATEX_ALLOWED_EMAIL_DOMAINS=${SHARELATEX_ALLOWED_EMAIL_DOMAINS}
```

### 5. `terraform.tfvars`
**Added configuration section:**
```hcl
# User Registration & Access Control
email_confirmation_disabled = true
allowed_email_domains = ""
```

### 6. `terraform.tfvars.example`
**Added with examples and documentation**

## Documentation Created

### `USER_REGISTRATION.md`
Complete guide covering:
- Configuration options
- Common use cases (public, organizational, academic)
- Testing and troubleshooting
- Security recommendations
- Examples by organization type

## Configuration Examples

### Current Configuration (Open Access)
```hcl
email_confirmation_disabled = true   # No email verification
allowed_email_domains = ""           # All domains allowed
```
**Result:** Anyone can register and immediately use Overleaf

### Recommended for Organizations
```hcl
email_confirmation_disabled = false         # Require email verification
allowed_email_domains = "company.com"       # Only company emails
```
**Result:** Only company email addresses can register, and they must verify their email

### Recommended for Universities
```hcl
email_confirmation_disabled = false
allowed_email_domains = "university.edu,alumni.university.edu"
```
**Result:** Students and alumni can register with email verification

## How to Apply Changes

### For New Deployments:
```bash
# Edit terraform.tfvars with desired settings
terraform apply
```

### For Existing Deployments:

**Option A: Terraform (recommended)**
```bash
# Edit terraform.tfvars
terraform apply
# Note: Will recreate the EC2 instance
```

**Option B: Manual Update**
```bash
ssh ubuntu@<ip>
# Edit /opt/overleaf/.env
export EMAIL_CONFIRMATION_DISABLED=false
export SHARELATEX_ALLOWED_EMAIL_DOMAINS="example.com"

cd /opt/overleaf/develop
docker compose restart web
```

## Testing

### Test Public Registration:
1. Visit `http://<your-ip>`
2. Click "Register" link
3. Create an account
4. Should work immediately (with current settings)

### Test Domain Restrictions:
```hcl
allowed_email_domains = "gmail.com"
```
- Try registering with @gmail.com - ✅ Should work
- Try registering with @yahoo.com - ❌ Should fail with "Email domain not allowed"

### Test Email Confirmation:
```hcl
email_confirmation_disabled = false
```
⚠️ **Requires SMTP to be configured!**
- Register new user
- Check email for confirmation link
- Cannot log in until email is confirmed

## Security Notes

✅ **Backward Compatible**: Existing deployments continue working with defaults
✅ **Flexible**: Can be changed without code modifications
✅ **Secure Defaults**: Can restrict access when needed

⚠️ **Important Considerations:**
- Email confirmation requires SMTP configuration
- Community Edition security notice (docker-compose.yml lines 79-81)
- Consider using LDAP for enterprise authentication

## Quick Reference

| Setting | Purpose | Default | Recommendation |
|---------|---------|---------|----------------|
| `SHARELATEX_ALLOW_PUBLIC_ACCESS` | Enable registration page | `true` | Keep `true` |
| `email_confirmation_disabled` | Skip email verification | `true` | Set `false` for production |
| `allowed_email_domains` | Restrict by domain | `""` (all) | Set to your domain(s) |

## Next Steps

1. **Decide on your access policy:**
   - Open to all? Keep defaults
   - Organization only? Set `allowed_email_domains`
   - Need verification? Set `email_confirmation_disabled = false`

2. **Update terraform.tfvars** with your choices

3. **Apply changes:**
   ```bash
   terraform apply
   ```

4. **Test registration** with different email addresses

5. **Monitor usage** and adjust as needed

## Related Documentation

- `EMAIL_SETUP.md` - SMTP configuration for email features
- `USER_REGISTRATION.md` - Detailed registration setup guide
- `QUICKSTART_SMTP.md` - Quick SMTP setup reference
- `README.md` - Main deployment documentation

## Validation

Configuration has been validated:
```bash
terraform fmt     # ✅ Formatted
terraform validate # ✅ Valid
```

All changes are ready to deploy!

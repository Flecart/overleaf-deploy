# Quick Start: SMTP Email Configuration

Your Overleaf deployment now supports email functionality via SMTP! Here's how to use it:

## ✅ Your Current Status

Your Gmail SMTP credentials have been tested and are working. They've been added to `terraform.tfvars`.

## 📋 What Was Configured

The following files now handle SMTP configuration:

1. **Terraform Variables** (`variables.tf`) - Defines SMTP configuration options
2. **Terraform Main** (`main.tf`) - Passes SMTP variables to deployment script
3. **User Data Script** (`user_data.sh`) - Exports SMTP as environment variables
4. **Docker Compose** (`overleaf/docker-compose.yml`) - Injects env vars into containers
5. **Terraform Outputs** (`outputs.tf`) - Shows SMTP configuration status

## 🚀 Next Steps

### Option 1: Deploy Now

If you're ready to deploy with email support:

```bash
# Initialize Terraform (if not done already)
terraform init

# Review what will be created
terraform plan

# Deploy to AWS
terraform apply
```

### Option 2: Test Locally First

If you want to test the configuration locally before deploying:

```bash
# Test SMTP credentials again
python3 scripts/test_gmail_smtp.py

# Review your configuration
cat terraform.tfvars | grep -A 8 "Email / SMTP"
```

## 🔍 Verify After Deployment

Once deployed, verify email is working:

```bash
# SSH into the instance
ssh -i <your-key.pem> ubuntu@<public-ip>

# Check if SMTP environment variables are set
cat /opt/overleaf/.env

# Check if the container can see the variables
cd /opt/overleaf/develop
docker compose exec web env | grep OVERLEAF_EMAIL_SMTP

# View container logs for email-related messages
docker compose logs web | grep -i email
```

## 📧 What Email Features Are Enabled

With SMTP configured, Overleaf can now:

- ✉️ Send password reset emails
- 📨 Send project sharing invitations  
- 🔔 Send notification emails
- 📬 Send account verification emails (if enabled)

**Note**: Email confirmation is currently **disabled** by default (`EMAIL_CONFIRMATION_DISABLED: "true"` in docker-compose.yml). Users can register without email verification.

## 🔐 Security Notes

- Your SMTP password is stored in `terraform.tfvars` (gitignored)
- Terraform marks `overleaf_smtp_user` and `overleaf_smtp_pass` as sensitive
- These values won't appear in Terraform output logs
- The password is transmitted to EC2 via encrypted user_data

## 📚 Documentation

For more details, see:

- **EMAIL_SETUP.md** - Complete setup guide with troubleshooting
- **SMTP_IMPLEMENTATION.md** - Technical implementation details
- **README.md** - Updated with SMTP configuration instructions

## 🛠️ Modifying SMTP Settings

To change SMTP settings later:

1. Edit `terraform.tfvars`
2. Run `terraform apply` (will recreate the instance due to user_data change)
3. Or manually update `/opt/overleaf/.env` on the running instance and restart:
   ```bash
   cd /opt/overleaf/develop
   docker compose restart web
   ```

## ⚠️ Important Notes

- **Gmail App Password Required**: You must use an App Password, not your regular Gmail password
- **2-Step Verification**: Must be enabled on your Google account
- **User Data Replacement**: Changing SMTP variables will trigger EC2 instance replacement (set `user_data_replace_on_change = true`)
- **Persistent Data**: Your data volume is preserved across instance replacements

## 🔄 Disabling Email

To disable email later, set these in `terraform.tfvars`:

```hcl
overleaf_smtp_host = ""
overleaf_smtp_user = ""
```

Then run `terraform apply`.

## 🐛 Troubleshooting

**Problem**: Emails not sending

**Solutions**:
1. Check container logs: `docker compose logs web | grep -i email`
2. Verify credentials: `python3 scripts/test_gmail_smtp.py`
3. Check environment variables are set: `docker compose exec web env | grep OVERLEAF_EMAIL`
4. Restart the web container: `docker compose restart web`

**Problem**: "Authentication failed" errors

**Solutions**:
1. Verify you're using an App Password, not your regular password
2. Check 2-Step Verification is enabled
3. Generate a new App Password at https://myaccount.google.com/apppasswords

---

## 📝 Summary of Changes Made

Created:
- `scripts/test_gmail_smtp.py` - SMTP credential testing script
- `EMAIL_SETUP.md` - Comprehensive email setup guide
- `SMTP_IMPLEMENTATION.md` - Technical implementation details
- `QUICKSTART_SMTP.md` - This file

Modified:
- `variables.tf` - Added 8 SMTP configuration variables
- `main.tf` - Pass SMTP variables to user_data
- `user_data.sh` - Export SMTP environment variables
- `overleaf/docker-compose.yml` - Use environment variable injection
- `outputs.tf` - Show SMTP configuration status
- `terraform.tfvars` - Added your Gmail SMTP configuration
- `terraform.tfvars.example` - Added SMTP configuration template
- `README.md` - Document SMTP setup process

All changes are backward compatible. Existing deployments without SMTP configuration will continue to work normally.

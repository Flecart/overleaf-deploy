# LiteLLM Proxy Setup for AI Tutor

This document explains how to use the LiteLLM proxy for cost tracking and model management with the AI Tutor feature.

## Overview

LiteLLM is a proxy server that sits between your Overleaf AI Tutor and OpenAI's API. It provides:

- **Cost tracking**: Monitor and limit spending on AI API calls
- **Budget control**: Set spending limits and alerts
- **Multiple models**: Support for all GPT models including the latest ones
- **Unified interface**: Use multiple AI providers (OpenAI, Anthropic) with one proxy

## Supported Models

The LiteLLM configuration includes the following models matching the AI Tutor dropdown:

### Primary Models (from AI Tutor)
- **gpt-4o** - Most capable GPT-4 model
- **gpt-4o-mini** - Faster, cheaper GPT-4 variant
- **gpt-4.1** - Next-generation GPT-4 (if available in your account)
- **gpt-4.1-mini** - Efficient GPT-4.1 variant (if available)
- **gpt-5.2** - Latest GPT-5 model (if available in your account)
- **gpt-5.2-chat-latest** - Latest GPT-5 chat model (if available)

### Legacy Models (for backwards compatibility)
- **gpt-4** - Original GPT-4
- **gpt-4-turbo** - GPT-4 Turbo
- **gpt-3.5-turbo** - GPT-3.5

### Optional: Claude Models (Anthropic)
If you uncomment the Claude models in the config and add your Anthropic API key:
- **claude-3-opus** - Most capable Claude model
- **claude-3-sonnet** - Balanced Claude model

## Configuration

### 1. Basic Setup (Direct OpenAI)

If you don't need LiteLLM, just set your OpenAI API key in `terraform.tfvars`:

```hcl
openai_api_key = "sk-proj-xxxxx"  # Your OpenAI API key
openai_base_url = ""               # Leave empty for direct OpenAI
```

### 2. Using LiteLLM Proxy (Recommended for Cost Tracking)

To enable LiteLLM proxy for cost tracking:

```hcl
# Your OpenAI API key (LiteLLM will use this to call OpenAI)
openai_api_key = "sk-proj-xxxxx"

# Point AI Tutor to use local LiteLLM proxy
openai_base_url = "http://localhost:4000"

# Optional: Set a custom master key (auto-generated if empty)
litellm_master_key = ""

# Optional: Add Anthropic API key for Claude models
anthropic_api_key = ""  # Only if you want Claude models
```

### 3. Advanced Configuration

The LiteLLM config file (`/opt/litellm/config.yaml` on the EC2 instance) includes:

```yaml
general_settings:
  master_key: ${LITELLM_MASTER_KEY}
  
  # Cost tracking and budget limits
  max_budget: 100.0  # Maximum total spend in USD
  budget_duration: 30d  # Reset budget every 30 days
```

You can modify these values in the `user_data.sh` script before deployment.

## Cost Tracking

Once LiteLLM is running, you can:

1. **View usage statistics** by checking LiteLLM logs:
   ```bash
   sudo docker logs litellm
   ```

2. **Access LiteLLM UI** (if enabled):
   ```
   http://your-instance-ip:4000/ui
   ```

3. **Monitor costs** through the LiteLLM dashboard or logs

4. **Set budget limits** in the config to prevent overspending

## Testing the Configuration

After deploying with LiteLLM enabled:

1. SSH into your instance:
   ```bash
   ssh -i ~/.ssh/overleaf-key.pem ubuntu@<your-instance-ip>
   ```

2. Check LiteLLM is running:
   ```bash
   sudo docker ps | grep litellm
   ```

3. Test the proxy:
   ```bash
   curl http://localhost:4000/health
   ```

4. Try using the AI Tutor in Overleaf - it should work through the proxy

## Troubleshooting

### LiteLLM not starting
Check logs: `sudo docker logs litellm`

### AI Tutor not connecting
- Verify `openai_base_url = "http://localhost:4000"` in your config
- Check that the LiteLLM container is running
- Ensure your OpenAI API key is valid

### Model not available errors
- Some models (gpt-4.1, gpt-5.2) may not be available in all OpenAI accounts yet
- Check your OpenAI account's model access at https://platform.openai.com/account/limits
- Remove unavailable models from the config if needed

## Cost Estimates

Approximate costs for AI Tutor usage (as of 2026):

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Use Case |
|-------|----------------------|------------------------|----------|
| gpt-4o | $2.50 | $10.00 | Best quality reviews |
| gpt-4o-mini | $0.15 | $0.60 | Most cost-effective |
| gpt-4 | $30.00 | $60.00 | Legacy, expensive |
| gpt-3.5-turbo | $0.50 | $1.50 | Basic reviews |

A typical paper review might use 2,000-5,000 tokens, costing:
- **gpt-4o-mini**: $0.001 - $0.003 per review (recommended)
- **gpt-4o**: $0.025 - $0.050 per review
- **gpt-4**: $0.150 - $0.300 per review

With a $100 monthly budget on gpt-4o-mini, you could process approximately **30,000-100,000 reviews**.

## Deployment

The LiteLLM proxy is automatically deployed and configured by the `user_data.sh` script when you set `openai_base_url = "http://localhost:4000"` in your `terraform.tfvars`.

To apply changes:
```bash
terraform apply
```

Or to update an existing instance, SSH in and redeploy the configuration.

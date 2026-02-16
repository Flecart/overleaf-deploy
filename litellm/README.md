# LiteLLM Proxy Configuration

This directory contains the configuration for the LiteLLM proxy server that gets installed on your Overleaf instance.

## What is LiteLLM?

LiteLLM is a proxy server that provides a unified interface for multiple AI model providers (OpenAI, Anthropic, Cohere, etc.). It offers:

- **Cost tracking** - Monitor API usage and costs across different models
- **Rate limiting** - Control request rates to prevent API quota issues
- **Caching** - Reduce API costs by caching repeated requests
- **Load balancing** - Distribute requests across multiple API keys or providers
- **Unified API** - Use the same OpenAI-compatible API for all providers

## Configuration

The `config.yaml` file is templated and deployed to `/opt/litellm/config.yaml` on the EC2 instance during deployment.

### Environment Variables

The following environment variables are injected into the config:

- `${OPENAI_API_KEY}` - Your OpenAI API key (from Terraform variables)
- `${LITELLM_MASTER_KEY}` - Master key for authenticating to the LiteLLM proxy (from Terraform variables)

### Default Configuration

By default, the proxy is configured with:

- **OpenAI models**: gpt-4, gpt-4-turbo, gpt-3.5-turbo
- **Port**: 4000 (accessible at `http://<your-ip>:4000`)
- **Request timeout**: 600 seconds
- **Verbose logging**: Enabled for debugging

### Adding More Models

To add support for other providers like Anthropic Claude, edit `config.yaml` and uncomment the relevant sections:

```yaml
  # Claude models
  - model_name: claude-3-opus
    litellm_params:
      model: anthropic/claude-3-opus-20240229
      api_key: ${ANTHROPIC_API_KEY}
```

Then add the `ANTHROPIC_API_KEY` to your Terraform variables.

## Using the Proxy

Once deployed, the LiteLLM proxy will be available at:

```
http://<your-ec2-ip>:4000
```

### Connecting Overleaf to LiteLLM

To use the local LiteLLM proxy instead of OpenAI directly, set the `openai_base_url` variable in your `terraform.tfvars`:

```hcl
openai_base_url = "http://localhost:4000"
```

This will configure Overleaf's AI Tutor to route all requests through the LiteLLM proxy.

### Making API Requests

You can make requests to the proxy using the OpenAI client library:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<your-ec2-ip>:4000",
    api_key="sk-1234"  # Your LITELLM_MASTER_KEY
)

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## Management

### Checking Status

SSH into your instance and check the service status:

```bash
systemctl status litellm
```

### Viewing Logs

```bash
journalctl -u litellm -f
```

### Restarting the Service

```bash
systemctl restart litellm
```

### Updating Configuration

1. Edit `/opt/litellm/config.yaml` on the server
2. Restart the service: `systemctl restart litellm`

## Advanced Features

### Database Integration

For production deployments, you can configure LiteLLM to use PostgreSQL for storing:
- API keys and budgets
- Request/response logs
- Usage analytics

Uncomment the database section in `config.yaml`:

```yaml
general_settings:
  database_url: "postgresql://user:password@localhost/litellm"
```

### Redis Caching

Enable Redis caching to reduce API costs:

```yaml
litellm_settings:
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379
```

## Troubleshooting

### Service Not Starting

Check the logs for errors:
```bash
journalctl -u litellm -n 50
```

Common issues:
- Missing Python packages: `pip3 install 'litellm[proxy]'`
- Port 4000 already in use: Change the port in the systemd service file
- Invalid API keys: Verify environment variables are set correctly

### Connection Refused

Make sure the security group allows traffic on port 4000:
```bash
# From your local machine
curl http://<your-ec2-ip>:4000/health
```

## Documentation

Full LiteLLM documentation: https://docs.litellm.ai/

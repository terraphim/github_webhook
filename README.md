# GitHub Webhook Handler

A Rust server that handles GitHub pull request webhooks.

## Setup

1. Clone the repository
2. Set environment variables: 

```bash
export GITHUB_WEBHOOK_SECRET=your_webhook_secret
export PORT=3000 # Optional, defaults to 3000
export WEBHOOK_SCRIPT=./pr_script.sh # Optional, defaults to ./pr_script.sh
```

3. Run the server

```bash
cargo run
```

2. Test with curl (simulating a GitHub webhook):

Generate signature (replace 'your_webhook_secret' with your secret)
```bash
echo -n '{"action":"opened","number":1,"pull_request":{"title":"Test PR","html_url":"https://github.com/user/repo/pull/1"}}' | openssl sha256 -hmac "your_webhook_secret" -hex
```

Send test webhook
```bash
curl -X POST http://localhost:3000/webhook \
-H "Content-Type: application/json" \
-H "X-Hub-Signature-256: sha256=<signature_from_above>" \
-d '{"action":"opened","number":1,"pull_request":{"title":"Test PR","html_url":"https://github.com/user/repo/pull/1"}}'
```

## Testing with GitHub

### Local Testing with Cloudflare Tunnel
1. Install Cloudflare CLI tool:
```bash
brew install cloudflare/cloudflare/cloudflared  # macOS
# or
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb  # Linux
```

2. Create a tunnel to expose your local server:
```bash
cloudflared tunnel --url http://localhost:3000
```

3. Copy the generated URL (like `https://your-tunnel.trycloudflare.com`)

### Configure GitHub Webhook
1. Go to your GitHub repository
2. Navigate to Settings > Webhooks > Add webhook
3. Configure the webhook:
   - Payload URL: Your Cloudflare tunnel URL + `/webhook` (e.g., `https://your-tunnel.trycloudflare.com/webhook`)
   - Content type: `application/json`
   - Secret: Same value as your `GITHUB_WEBHOOK_SECRET`
   - Events: Select "Pull requests"
   - Active: Check this box

4. Click "Add webhook"

Now when you:
- Create a new PR
- Update an existing PR
GitHub will send webhooks to your local server through the Cloudflare tunnel.

### Manual Testing
You can still use the test script for local testing:
```bash
./test_webhook.sh
```

## Testing

Run the tests:
```bash
cargo test
```

To run with 1password cli: 
```bash
op run --env-file demo.env -- cargo run
```

To run with 1password cli and test webhook over tunnel: 
```bash
op run --env-file demo.env -- ./test_webhook_over_tunnel.sh
```
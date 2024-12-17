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

## Testing

Run the tests:
```bash
cargo test
```
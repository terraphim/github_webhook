use anyhow::Result;
use salvo::prelude::*;
use serde::{Deserialize, Serialize};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::env;
use async_process::Command;
use tracing::{info, error};

#[derive(Debug, Deserialize)]
struct PullRequest {
    action: String,
    number: i64,
    pull_request: PullRequestDetails,
}

#[derive(Debug, Deserialize)]
struct PullRequestDetails {
    title: String,
    html_url: String,
}

#[derive(Debug, Serialize)]
struct WebhookResponse {
    message: String,
    status: String,
}

async fn verify_signature(secret: &str, signature: &str, body: &[u8]) -> Result<bool> {
    let signature = signature.replace("sha256=", "");
    let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes())?;
    mac.update(body);
    let result = mac.finalize().into_bytes();
    let hex_signature = hex::encode(result);
    
    Ok(hex_signature == signature)
}

async fn execute_script(pr_number: i64, pr_title: &str, pr_url: &str) -> Result<()> {
    let script_path = env::var("WEBHOOK_SCRIPT").unwrap_or_else(|_| "./pr_script.sh".to_string());
    
    let output = Command::new(&script_path)
        .arg(pr_number.to_string())
        .arg(pr_title)
        .arg(pr_url)
        .output()
        .await?;
    
    if !output.status.success() {
        let error_message = String::from_utf8_lossy(&output.stderr);
        error!("Script execution failed: {}", error_message);
        return Err(anyhow::anyhow!("Script execution failed"));
    }
    
    info!("Script executed successfully");
    Ok(())
}

#[handler]
async fn handle_webhook(req: &mut Request, res: &mut Response) -> Result<(), StatusError> {
    let github_secret = match env::var("GITHUB_WEBHOOK_SECRET") {
        Ok(secret) => secret,
        Err(_) => {
            error!("GITHUB_WEBHOOK_SECRET environment variable not set");
            return Err(StatusError::internal_server_error());
        }
    };

    let signature = match req.headers().get("x-hub-signature-256").and_then(|h| h.to_str().ok()) {
        Some(sig) => sig.to_string(),
        None => {
            error!("Missing or invalid X-Hub-Signature-256 header");
            return Err(StatusError::bad_request());
        }
    };

    let body = match req.payload().await {
        Ok(bytes) => bytes,
        Err(e) => {
            error!("Failed to read request body: {}", e);
            return Err(StatusError::bad_request());
        }
    };

    match verify_signature(&github_secret, &signature, &body).await {
        Ok(true) => (),
        Ok(false) => {
            error!("Invalid signature");
            return Err(StatusError::forbidden());
        }
        Err(e) => {
            error!("Signature verification error: {}", e);
            return Err(StatusError::internal_server_error());
        }
    }

    let pull_request: PullRequest = match serde_json::from_slice(&body) {
        Ok(pr) => pr,
        Err(e) => {
            error!("Failed to parse webhook payload: {}", e);
            return Err(StatusError::bad_request());
        }
    };

    if pull_request.action == "opened" || pull_request.action == "synchronize" {
        match execute_script(
            pull_request.number,
            &pull_request.pull_request.title,
            &pull_request.pull_request.html_url
        ).await {
            Ok(_) => {
                let response = WebhookResponse {
                    message: "Webhook processed successfully".to_string(),
                    status: "success".to_string(),
                };
                res.render(Json(response));
            }
            Err(e) => {
                error!("Script execution failed: {}", e);
                return Err(StatusError::internal_server_error());
            }
        }
    }

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt().init();

    let router = Router::new().push(
        Router::with_path("webhook").post(handle_webhook)
    );
    
    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr = format!("127.0.0.1:{}", port);
    
    info!("Server starting on {}", addr);
    let acceptor = TcpListener::new(addr).bind().await;
    Server::new(acceptor).serve(router).await;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use salvo::prelude::*;
    use salvo::test::{ResponseExt, TestClient};

    async fn setup_test_server() -> Router {
        env::set_var("GITHUB_WEBHOOK_SECRET", "test_secret");
        Router::new().push(Router::with_path("webhook").post(handle_webhook))
    }

    #[tokio::test]
    async fn test_valid_webhook() {
        let service = Service::new(setup_test_server().await);
        let payload = r#"{"action":"opened","number":1,"pull_request":{"title":"Test PR","html_url":"https://github.com/user/repo/pull/1"}}"#;
        
        // Generate valid signature
        let mut mac = Hmac::<Sha256>::new_from_slice(b"test_secret").expect("HMAC initialization failed");
        mac.update(payload.as_bytes());
        let signature = format!("sha256={}", hex::encode(mac.finalize().into_bytes()));

        let resp = TestClient::post("http://127.0.0.1:5800/webhook")
            .add_header("content-type", "application/json", false)
            .add_header("x-hub-signature-256", signature, false)
            .body(payload)
            .send(&service)
            .await;

        assert_eq!(resp.status_code, Some(StatusCode::OK));
    }

    #[tokio::test]
    async fn test_invalid_signature() {
        let service = Service::new(setup_test_server().await);
        let payload = r#"{"action":"opened","number":1,"pull_request":{"title":"Test PR","html_url":"https://github.com/user/repo/pull/1"}}"#;

        let resp = TestClient::post("http://127.0.0.1:5800/webhook")
            .add_header("content-type", "application/json", false)
            .add_header("x-hub-signature-256", "sha256=invalid", false)
            .body(payload)
            .send(&service)
            .await;

        assert_eq!(resp.status_code, Some(StatusCode::FORBIDDEN));
    }

    #[tokio::test]
    async fn test_missing_signature() {
        let service = Service::new(setup_test_server().await);
        let payload = r#"{"action":"opened","number":1,"pull_request":{"title":"Test PR","html_url":"https://github.com/user/repo/pull/1"}}"#;

        let resp = TestClient::post("http://127.0.0.1:5800/webhook")
            .add_header("content-type", "application/json", false)
            .body(payload)
            .send(&service)
            .await;

        assert_eq!(resp.status_code, Some(StatusCode::BAD_REQUEST));
    }
}
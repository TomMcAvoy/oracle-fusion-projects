# Self-Hosted GitHub Actions Runner with Vault OIDC Integration

## Overview
This guide explains how to securely use a self-hosted GitHub Actions runner with a private HashiCorp Vault instance for OIDC-based secret injection, without exposing Vault to the public internet.

---

## Steps

### 1. Set Up Vault (Dev Mode for Testing)
- Vault runs in dev mode, unsealed, and listens on 127.0.0.1:8200.
- OIDC is configured for GitHub Actions with a role bound to your repo.

### 2. Register a Self-Hosted Runner
- Go to your repo: **Settings → Actions → Runners → New self-hosted runner**.
- Select Linux, x64, and follow the instructions, or use the provided automation script.

### 3. Automate Runner Setup (Recommended)
- Use `scripts/setup-gh-runner.sh` to download, register, and start the runner:
  ```bash
  bash scripts/setup-gh-runner.sh
  ```
- Requires the GitHub CLI (`gh`). Install with:
  ```bash
  bash scripts/install-gh-cli.sh
  gh auth login
  ```

### 4. Update Workflow for OIDC and Self-Hosted Runner
- Workflow file: `.github/workflows/ci-cd.yml`
- Key changes:
  - `runs-on: self-hosted`
  - Add `permissions: id-token: write, contents: read`
  - Use Vault OIDC (jwt) method:
    ```yaml
    - name: Fetch secrets from Vault (OIDC)
      uses: hashicorp/vault-action@v2
      with:
        url: http://127.0.0.1:8200
        method: jwt
        role: github-actions
        secrets: |
          secret/data/wildfly WILDFLY_USER | WILDFLY_USER;
          secret/data/wildfly WILDFLY_PASS | WILDFLY_PASS;
    ```

### 5. Run Your Workflow
- Push to your repo or trigger the workflow.
- The self-hosted runner will fetch secrets from Vault using OIDC.

---

## Security Notes
- Vault is only accessible to the runner on localhost or the private network.
- No Vault secrets are exposed to the public internet.
- OIDC ensures short-lived, auditable credentials for CI/CD.

---

## Troubleshooting
- Ensure the runner and Vault are on the same host/network.
- If the runner fails to fetch secrets, check Vault logs and OIDC role config.
- For production, use a persistent Vault backend and secure the runner host.

---

## References
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners)
- [HashiCorp Vault OIDC Auth](https://developer.hashicorp.com/vault/docs/auth/jwt)
- [hashicorp/vault-action](https://github.com/hashicorp/vault-action)

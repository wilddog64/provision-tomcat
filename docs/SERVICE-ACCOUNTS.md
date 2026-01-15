# Configuring the Tomcat Windows Service Account

By default the `provision-tomcat` role installs Tomcat as a Windows service that runs under `LocalSystem`. Production environments often require a managed account with limited privileges. The role now exposes two variables you can override:

```yaml
tomcat_service_account_username: 'MYDOMAIN\\svc_tomcat'
tomcat_service_account_password: '{{ lookup("env", "TOMCAT_SERVICE_PASSWORD") }}'
```

Leave `tomcat_service_account_username` empty or set to `LocalSystem` to keep the default context.

## Providing Credentials Securely

You rarely want to commit service credentials into a playbook. Below are common ways to inject the username/password.

### AWS Secrets Manager

1. Create a secret with JSON keys:
   ```json
   {"username": "MYDOMAIN\\svc_tomcat", "password": "super-secret"}
   ```
2. Export an IAM role/credentials that allow `secretsmanager:GetSecretValue`.
3. In your playbook vars:
   ```yaml
   - hosts: windows
     vars:
       tomcat_service_account_username: "{{ lookup('aws_secretsmanager', 'prod/tomcat-service', json_key='username') }}"
       tomcat_service_account_password: "{{ lookup('aws_secretsmanager', 'prod/tomcat-service', json_key='password') }}"
     roles:
       - provision-tomcat
   ```

### Azure Key Vault

1. Store the username/password as separate secrets or a JSON secret.
2. Use the `azure_keyvault_secret` lookup:
   ```yaml
   vars:
     tomcat_service_account_username: "{{ lookup('azure_keyvault_secret', 'svc-tomcat-user', vault_url='https://myvault.vault.azure.net/') }}"
     tomcat_service_account_password: "{{ lookup('azure_keyvault_secret', 'svc-tomcat-pass', vault_url='https://myvault.vault.azure.net/') }}"
   ```
3. Authenticate by exporting `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_CLIENT_SECRET` for the Key Vault-enabled service principal.

### HashiCorp Vault

1. Write the credentials to a KV path (e.g., `secret/data/services/tomcat`).
2. Use the `hashi_vault` lookup:
   ```yaml
   vars:
     tomcat_service_account_username: "{{ lookup('hashi_vault', 'secret/data/services/tomcat', field='username') }}"
     tomcat_service_account_password: "{{ lookup('hashi_vault', 'secret/data/services/tomcat', field='password') }}"
   ```
3. Configure Vault access via token, AppRole, or whichever auth method you already use for Ansible.

### General Guidelines

- Never store plaintext passwords in Git; rely on dynamic lookups or Vault-encrypted vars.
- Make sure the service account has the “Log on as a service” right on the target Windows hosts.
- For domain accounts, use the `DOMAIN\\username` format. For Managed Service Accounts (gMSA), leave the password blank and set the username to the gMSA (e.g., `mygmsa$`).

Once the variables are set, the role automatically reconfigures both the primary Tomcat service and the temporary candidate service (when enabled) to run under the supplied account.

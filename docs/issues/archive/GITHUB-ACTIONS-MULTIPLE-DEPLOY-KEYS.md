# GitHub Actions: Repository Not Found (Multiple Deploy Keys)

## Problem
When using GitHub Actions to check out multiple private repositories using SSH Deploy Keys, you may encounter the following error during the `checkout` step:

```
ERROR: Repository not found.
Error: fatal: Could not read from remote repository.
Please make sure you have the correct access rights and the repository exists.
```

## Cause: Ambiguous SSH Keys
This issue occurs when the Git environment has access to multiple SSH keys simultaneously, leading to authentication "pollution":

1.  **SSH Agent Conflict:** Using `webfactory/ssh-agent` loads multiple keys into a single agent. When Git connects to GitHub, the agent offers keys sequentially. If GitHub sees a valid key that *doesn't* have access to the specific repo being requested, it returns "Repository not found" instead of allowing the agent to try the next key.
2.  **Credential Persistence:** By default, `actions/checkout` persists the SSH key to the local Git configuration. If the first checkout step succeeds, its key remains in the environment. The second checkout step may then attempt to use that "persisted" key for the wrong repository, causing the same "Repository not found" error.

## Solution: SSH Config Aliases

The most reliable way to handle multiple deploy keys is to avoid `actions/checkout` for private dependencies entirely. Instead, manually configure the `~/.ssh/config` file to map specific **Host Aliases** to specific **Identity Files**.

### 1. Write Keys and Config
Create a step to write your secrets to files and generate a config block:

```yaml
- name: Install SSH Keys and Config
  run: |
    mkdir -p ~/.ssh
    
    # Write Key A
    echo "${{ secrets.REPO_A_KEY }}" > ~/.ssh/id_repo_a
    chmod 600 ~/.ssh/id_repo_a
    
    # Write Key B
    echo "${{ secrets.REPO_B_KEY }}" > ~/.ssh/id_repo_b
    chmod 600 ~/.ssh/id_repo_b
    
    # Create Config
    cat <<EOF > ~/.ssh/config
    Host repo-a-alias
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_repo_a
      IdentitiesOnly yes
    
    Host repo-b-alias
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_repo_b
      IdentitiesOnly yes
    EOF
    
    # Scan GitHub keys
    ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### 2. Clone using Aliases
Use standard `git clone` commands with the aliases defined above. Git will see `repo-a-alias` and automatically use the correct key.

```yaml
- name: Checkout Repo A
  run: git clone repo-a-alias:user/repo-a.git roles/repo-a

- name: Checkout Repo B
  run: git clone repo-b-alias:user/repo-b.git roles/repo-b
```

## Why this works
This approach removes all ambiguity. You explicitly tell Git: "When connecting to `repo-a-alias`, MUST use `id_repo_a`". It bypasses the SSH agent's guessing logic and `actions/checkout`'s persistence issues entirely.


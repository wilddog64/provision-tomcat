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

## Solution: Isolated Checkout Steps

To solve this, you must isolate each checkout operation:
1.  **Avoid Global Agents:** Remove `ssh-agent` steps.
2.  **Explicit Keys:** Provide the `ssh-key` directly to each `actions/checkout` step.
3.  **Disable Persistence:** Set `persist-credentials: false` to ensure each step cleans up its key before the next one starts.

### Incorrect Configuration (Fails)
```yaml
- name: Setup SSH Keys
  uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: |
      ${{ secrets.REPO_A_KEY }}
      ${{ secrets.REPO_B_KEY }}

- name: Checkout Repo A
  uses: actions/checkout@v4
  with:
    repository: user/repo-a

- name: Checkout Repo B
  uses: actions/checkout@v4
  with:
    repository: user/repo-b
```

### Correct Configuration (Works)
```yaml
- name: Checkout Repo A
  uses: actions/checkout@v4
  with:
    repository: user/repo-a
    ssh-key: ${{ secrets.REPO_A_KEY }}  # Explicit key for this repo
    persist-credentials: false          # Critical: Do not persist key to next step

- name: Checkout Repo B
  uses: actions/checkout@v4
  with:
    repository: user/repo-b
    ssh-key: ${{ secrets.REPO_B_KEY }}  # Explicit key for this repo
    persist-credentials: false          # Critical: Do not persist key to next step
```

## Reference
This approach ensures that the Git command for each checkout uses strictly the credential authorized for that repository.

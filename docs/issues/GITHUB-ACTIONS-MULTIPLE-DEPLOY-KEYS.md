# GitHub Actions: Repository Not Found (Multiple Deploy Keys)

## Problem
When using GitHub Actions to check out multiple private repositories using SSH Deploy Keys, you may encounter the following error during the `checkout` step:

```
ERROR: Repository not found.
Error: fatal: Could not read from remote repository.
Please make sure you have the correct access rights and the repository exists.
```

## Cause: Ambiguous SSH Keys
This issue occurs when using `webfactory/ssh-agent` (or similar actions) to load multiple SSH keys into the SSH agent at once. 

1.  **Agent Logic:** When Git connects to GitHub, the SSH agent offers the keys one by one.
2.  **Ambiguity:** If the agent offers Key A (for Repo A) when trying to clone Repo B, GitHub authenticates the user but denies access to Repo B (because Key A is not authorized for Repo B).
3.  **Failure:** Instead of rejecting the key and letting the agent try Key B, GitHub returns "Repository not found" (security measure). Git interprets this as a fatal error and stops.

## Solution: Isolated Checkout Steps

Do not use `ssh-agent` to load all keys globally. Instead, provide the specific SSH key to the `actions/checkout` step directly. This configures Git to use *only* that specific key for that specific command, eliminating ambiguity.

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

- name: Checkout Repo B
  uses: actions/checkout@v4
  with:
    repository: user/repo-b
    ssh-key: ${{ secrets.REPO_B_KEY }}  # Explicit key for this repo
```

## Reference
This approach ensures that the Git command for each checkout uses strictly the credential authorized for that repository.

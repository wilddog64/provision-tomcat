# AWS Infrastructure Drift and Dynamic Binding (2026-02-14)

## Problem: Fragile CI due to Ephemeral Sandbox Resource ID Changes

When an AWS sandbox environment is recreated or refreshed (e.g., after an expiration), critical infrastructure resource IDs such as `subnet_id`, `security_group_ids`, and potentially `ami-id` often change. Our current Test Kitchen configuration (`.kitchen.yml`) hardcodes these values.

This leads to CI fragility:
- **Error Example**: `The subnet ID 'subnet-0bf736b950e25a150' does not exist in the specified region us-east-1.`
- **Impact**: Tests fail because the hardcoded resource IDs are no longer valid in the refreshed environment.
- **Manual Burden**: Developers are currently required to manually obtain these new IDs from the AWS console and update `.kitchen.yml` each time the sandbox shifts.

## Distinction: Credentials vs. Resource IDs

It is critical to distinguish between:
-   **AWS Credentials**: These are the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` (OAuth keys) used to authenticate with AWS. These change upon sandbox recreation.
    -   **Update Mechanism**: Currently, manual `make sync-aws` (after local sandbox refresh) to push to GitHub Secrets. This is a hard constraint due to the dynamic nature of OAuth keys and the security model.
-   **AWS Infrastructure Resource IDs**: These are identifiers for specific resources like `subnet-XXX`, `sg-YYY`, `ami-ZZZ`. These also change upon sandbox recreation.
    -   **Current Update Mechanism**: Manual update of `.kitchen.yml`. This is the source of CI fragility.

## Solution: Hybrid Zero-Touch Sync Strategy

To mitigate this CI fragility and reduce manual intervention for resource ID updates (while acknowledging the necessary manual credential sync), we propose a "Hybrid Zero-Touch Sync" architectural pattern:

1.  **Manual Credential Sync (Initial Step)**:
    *   `make sync-aws` will remain a required manual step performed locally by the user.
    *   This is explicitly for refreshing OAuth/session tokens and pushing them to GitHub Secrets, acknowledging the hard constraint of dynamic credential updates when the sandbox is recreated.
    *   Local `make` targets will incorporate a credential validation check to fail fast and prompt the user if `make sync-aws` is needed.

2.  **Automatic Resource Discovery (Post-Credential Sync)**:
    *   After successful manual credential sync, subsequent local `make` targets for AWS integration will dynamically discover the current `subnet_id`, `security_group_ids`, `ami-id`, and `availability_zone` from the live sandbox using AWS APIs (`aws ec2 describe-subnets`, `describe-security-groups`, `describe-images`).
    *   These IDs will be discovered based on tags or naming conventions applied to the sandbox resources (e.g., "OwnedBy: AGC-Sandbox", "Project: Tomcat-Provisioning").
    *   The dynamically discovered IDs will then be passed to `kitchen test` via environment variables or used to generate a temporary Kitchen configuration override (`.kitchen.local.yml`).

### Benefits:
-   **Reduces Fragility**: CI becomes self-healing against infrastructure drift for resource IDs.
-   **Improved Workflow**: Less manual intervention for developers.
-   **Balances Security & Automation**: Explicit credential control combined with automated resource binding.
-   **Aligns with Patterns**: Enhances "Test Orchestration Pattern" and "Zero-Touch Secret Sync" from `systemPatterns.md`.

## Next Steps:
-   Implement `check-aws-credentials` make target.
-   Implement `discover-aws-resources` make target using AWS CLI.
-   Modify `.kitchen.yml` to consume dynamic resource IDs.
-   Integrate into `ci.yml` for consistent CI behavior.
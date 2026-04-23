# AWS candidate promotion fix is not yet delivered to the branch

## What was tested / attempted

- Reviewed the current discussion around `make test-aws-upgrade-candidate` failing with:

```text
-----> Test Kitchen is finished. (0m2.33s)
Revoking ingress for runner IP: 216.9.30.23
make: *** [test-aws-upgrade-candidate] Error 127
```

- Compared that failure with the local repository state and later live-run evidence.
- Verified that the promotion-helper changes and successful live retries exist only in the local `aws-dev` commit stack, which is still ahead of `origin/aws-dev`.

## Actual output

Current local branch divergence:

```text
## aws-dev...origin/aws-dev [ahead 21]
```

Earlier failure that still represents the undelivered branch state:

```text
-----> Test Kitchen is finished. (0m2.33s)
Revoking ingress for runner IP: 216.9.30.23
make: *** [test-aws-upgrade-candidate] Error 127
```

## Root cause

- The original `Error 127` defect was caused by the promotion helper invoking Python content incorrectly from the `Makefile` recipe.
- That implementation has since been corrected locally and validated with later live AWS runs.
- However, the corrected implementation has not yet been pushed to the branch that operators would rely on, so the bug remains undelivered from an operator perspective.

## Why this matters

- Operators can still observe the historical `Error 127` behavior if they run from the remote branch state instead of the local working tree.
- Reporting the bug as "fixed" before the branch contains the fix creates confusion about what is actually usable.
- The supported AWS candidate workflow is not reliably consumable until the validated commit stack is delivered.

## Recommended follow-up

- Push the validated local `aws-dev` commit stack containing the promotion-helper fix and live-test documentation.
- Re-run `make test-aws-upgrade-candidate-latest` from the delivered branch state to confirm the remote branch matches the validated local result.

## Related

- Original helper failure: `docs/issues/2026-04-22-aws-candidate-promotion-helper-error-127.md`
- Successful later live run: `scratch/live-test-aws-upgrade-candidate-latest-now-20260422-181629.log`

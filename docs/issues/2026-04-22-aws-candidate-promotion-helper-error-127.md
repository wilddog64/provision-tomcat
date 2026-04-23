# AWS candidate promotion helper failed with `Error 127`

## What was tested / attempted

- Ran the new convenience target:

```bash
make test-aws-upgrade-candidate-latest
```

- The AWS candidate workflow successfully created the instance, converged the candidate path, and finished Kitchen verification.
- The run then failed immediately during the first implementation of the AWS promotion helper.

## Actual output

Observed failure from `scratch/live-test-aws-upgrade-candidate-latest-20260422-050906.log`:

```text
Finished verifying <upgrade-candidate-aws-disk-aws-minimal-win-disk> (0m0.12s).
-----> Test Kitchen is finished. (0m1.16s)
/bin/bash: import: command not found
=== Cleaning up... ===
...
make[1]: *** [test-aws-upgrade-candidate] Error 127
make: *** [test-aws-upgrade-candidate-latest] Error 2
```

## Root cause

- The initial AWS promotion helper embedded Python source in a shell heredoc inside the `Makefile` recipe.
- In that form, the shell wound up interpreting Python lines directly.
- The first visible symptom was:

```text
/bin/bash: import: command not found
```

- That shell error aborted the target with exit `127` after candidate verification completed.

## Why this matters

- The candidate stage itself had already succeeded, so this was a promotion-helper implementation bug rather than an AWS provisioning failure.
- It created a misleading result where the workflow looked healthy up to verification, then failed abruptly in the local orchestration layer.

## Resolution status

- Fixed later by replacing the fragile heredoc-based helper with a simpler inventory/vars generation path in `Makefile`.
- Subsequent live retries moved past this exact `127` failure and validated the full promote-and-verify path successfully.

## Related

- Successful later run: `scratch/live-test-aws-upgrade-candidate-latest-retry3-20260422-055619.log`
- Promotion spec: `docs/plans/2026-04-22-aws-candidate-promotion-validation.md`

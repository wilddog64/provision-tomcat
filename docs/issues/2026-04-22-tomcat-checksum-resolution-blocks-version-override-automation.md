# Tomcat checksum resolution blocks version-override automation

## What was tested / attempted

- Added configurable Java/Tomcat version inputs to the upgrade-oriented `Makefile` targets.
- Ran live AWS candidate tests using explicit Tomcat version overrides.
- Attempted to rely on version changes alone without always supplying Tomcat archive URLs and SHA-512 checksums.

## Actual output

During live testing, version overrides were not enough by themselves:

```text
Error downloading 'https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115-windows-x64.zip'
to 'D:/temp/apache-tomcat-9.0.115.zip': The remote server returned an error: (404) Not Found.
```

And when switching to the Apache archive URL for a newer version:

```text
The checksum for https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.117/bin/apache-tomcat-9.0.117-windows-x64.zip
did not match
'77e79950cc7fd1b00888fb351e542ec8235c071e5a021b980b5dabc3023a23bdee42beccaedf529c530c8ec85bab13d83662b8df22ac3dc596f295526375f5d5',
it was
'f8b6e8ca5d703fbab508cf09e0e9589f556a80c1ac5e5d3b62ef2e643e7e4598c20b4b6ef9e04a280827dc21199d48d73fa42608396971c5263adee5242d0084'
```

The target only passed when explicit URL and checksum overrides were provided.

## Root cause

- Tomcat version selection is now configurable, but Tomcat URL/checksum resolution is still effectively static.
- `defaults/main.yml` pins a default `tomcat_download_url` pattern and `tomcat_checksum` for the repository default release.
- Older releases may need `archive.apache.org` instead of `dlcdn.apache.org`.
- Newer releases require their own SHA-512 values, but the workflow does not resolve them automatically.
- `ETag` or generic HTTP cache metadata does not replace the security requirement for a trusted expected checksum.

## Why this is a bug

- The new version-override interface is incomplete unless Tomcat metadata resolution also becomes automatic.
- In practice, version automation is blocked unless callers manually discover and pass `TOMCAT_*_DOWNLOAD_URL` and `TOMCAT_*_CHECKSUM`.
- This prevents CI and automation from treating version overrides as a first-class input.

## Recommended follow-up

- Automatically resolve Tomcat download URLs from the requested version.
- Automatically resolve the expected SHA-512 checksum from the official Apache Tomcat release metadata or checksum file.
- Decide archive vs. `dlcdn` source based on version availability.
- Preserve checksum verification; do not weaken the download integrity gate.

## Related

- Spec: `docs/plans/2026-04-22-configurable-upgrade-version-targets.md`
- Live findings: `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`

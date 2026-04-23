# Local validation blocked by missing Bundler 4.0.6

## What was tested / attempted

- After delivering the `aws-dev` commit stack, attempted to capture local validation proof with:

```bash
make syntax
```

- Also checked whether the copied `scripts/tests`, touched `.sh` file shellcheck scope, and `_agent_audit` tooling exist in this repository.

## Actual output

```text
--- make syntax
Installing Ruby dependencies...
`/Users/cliang` is not writable.
Bundler will use `/tmp/bundler20260422-34062-w8aei434062' as your home directory temporarily.
There was an error while trying to write to
`/Users/cliang/src/gitrepo/personal/ansible/provision-tomcat/Gemfile.lock`.
Underlying OS system call raised an EPERM error.
/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/rubygems.rb:283:in `find_spec_for_exe': Could not find 'bundler' (4.0.6) required by your /Users/cliang/src/gitrepo/personal/ansible/provision-tomcat/Gemfile.lock. (Gem::GemNotFoundException)
To update to the latest version installed on your system, run `bundle update --bundler`.
To install the missing version, run `gem install bundler:4.0.6`
	from /System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/ruby/2.6.0/rubygems.rb:302:in `activate_bin_path'
	from /usr/bin/bundle:23:in `<main>'
make: *** [deps] Error 1
--- bats availability / suites
scripts/tests not present in provision-tomcat
--- shellcheck scope
no touched .sh files in delivered commit stack
--- _agent_audit availability
_agent_audit not found in provision-tomcat repo
```

## Root cause

- This repository's local validation path depends on Bundler `4.0.6` from `Gemfile.lock`.
- The current shell environment resolved to system Ruby/Bundler, which does not provide that Bundler version.
- The attempted dependency step also hit a local write-permission problem around `Gemfile.lock`.
- The copied `scripts/tests` and `_agent_audit` proof steps do not exist in `provision-tomcat`, so they are not directly runnable here.

## Recommended follow-up

- Restore the expected Ruby/Bundler toolchain for this repo before relying on `make syntax` or other Bundler-backed checks.
- If operator proof requirements should differ between `k3d-manager` and `provision-tomcat`, separate those instructions so the validation checklist matches the repo.

## Related

- Delivered branch tip: `ffdbfd2`
- Prior live AWS validation log: `scratch/live-test-aws-upgrade-candidate-latest-now-20260422-181629.log`

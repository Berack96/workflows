# workflows

My personal GitHub workflows for generating tags and for checking security problems: reusable workflows
(`workflow_call`) for PR titles, tests, security checks and releases.

## Usage

This repository is private: only repositories owned by `Berack96` can call it, with **Settings → Actions → General →
Access → Accessible from repositories owned by the user** turned on here.

A job calls a workflow with `uses`, pinned to a commit with its version in a comment, and grants it the permissions it
needs (listed for each workflow below):

```yaml
jobs:
  title:
    uses: Berack96/workflows/.github/workflows/pr-title.yml@<sha> # vX.Y.Z
```

The workflows contain all their scripts: nothing is loaded from this repository at another ref, so the pinned commit
is all that runs.

## Workflows

### `pr-title.yml`

Checks the title of a PR, which becomes the subject of the squash commit and decides the next version in
`release.yml`. Permissions: none.

| Input | Default | |
| --- | --- | --- |
| `pattern` | `^(feat\|fix\|docs\|refactor\|test\|chore)(\([^)]+\))?!?: .+` | Bash regex the title must match |

### `test.yml`

Runs the lint and test commands of the caller. Permissions: `contents: read`.

| Input | Default | |
| --- | --- | --- |
| `run` | required | Commands (bash, one per line) |
| `env` | | Environment variables for the whole job, one `NAME=value` per line |
| `mise` | `false` | Install the tools of the repository's mise config (pinned mise) |
| `rust-cache` | `false` | Cache the Rust builds (`Swatinem/rust-cache`) |
| `artifact` | | Name of an artifact to upload after the tests, for the next jobs |
| `artifact-path` | | Files of the artifact |

### `security.yml`

Security checks, each one can be turned off. The dependency checks run only when their lockfiles are tracked in the
repository; any known vulnerability fails them. The run summary has a table of the results, with the output of the
failed checks. Permissions: `contents: read`.

| Input | Default | Check |
| --- | --- | --- |
| `secrets` | `true` | Committed secrets (gitleaks) |
| `actions` | `true` | GitHub Actions workflows (zizmor, high severity) |
| `iac` | `true` | Dockerfiles and other infrastructure as code (Trivy, high and critical) |
| `rust` | `true` | `Cargo.lock` (cargo-deny: all checks with a `deny.toml`, without it all but licenses) |
| `python` | `true` | `uv.lock`, `poetry.lock`, `Pipfile.lock`, `pdm.lock`, `requirements.txt` (OSV-Scanner) |
| `javascript` | `true` | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lock` (OSV-Scanner) |
| `java` | `true` | `pom.xml`, `gradle.lockfile` (OSV-Scanner; Gradle needs dependency locking) |
| `go` | `true` | `go.mod` (OSV-Scanner) |

### `failure-issue.yml`

Opens an issue for a failed run, or comments the one already open with the same title: a failed scheduled run notifies
only who last edited the cron. Permissions: `issues: write`.

| Input | Default | |
| --- | --- | --- |
| `title` | required | Title of the issue |

### `release.yml`

Tags and GitHub releases, in two modes:

- `staging`, on a push to the default branch: a staging tag on the pushed commit and, if `prerelease` is on, a
  pre-release with the files of an artifact. A run on a commit the branch has already moved past does nothing.
- `production`, by hand: the release of a staging tag, without rebuilding, with the files of its pre-release. Only an
  admin of the repository can run it, and the staging tag must be on the default branch, after the latest release, with
  a passed run of the staging workflow. With `staging: false` it releases the head of the default branch instead.

There is always at most one pre-release: the one of the latest staging tag after the latest release. Any other
pre-release of the repository is deleted. The release notes come from the commit titles since the latest release
(git-cliff, conventional commits). Re-running a failed run is safe: tags and releases already created are checked and
kept.

Tags:

| | `calver` | `semver` |
| --- | --- | --- |
| `staging-scheme` | `<prefix>-YYYY.MM-build.NNN` (default) | `<next release>-<prefix>.N` |
| `release-scheme` | `vYYYY.MM.N` | `vX.Y.Z` (default): `!` bumps X, `feat` bumps Y, anything else Z |

Dates are the commit dates in UTC. With no release yet, semver starts from `v0.0.0`.

Permissions: `contents: write`, `pull-requests: read`, `actions: read`.

| Input | Default | |
| --- | --- | --- |
| `mode` | required | `staging` or `production` |
| `staging` | `true` | Use staging tags; off, `production` releases the head of the default branch |
| `staging-prefix` | `staging` | Name in the staging tags |
| `staging-scheme` | `calver` | `calver` or `semver` |
| `release-scheme` | `semver` | `semver` or `calver` |
| `prerelease` | `true` | Keep a pre-release on the latest staging tag; off, staging creates only tags |
| `artifact` | | `staging`: artifact whose files are attached to the pre-release, and then to the release |
| `assets-notes` | | Text added to the release notes when there are attached files |
| `tag` | | `production`: staging tag to release (empty for the latest) |
| `staging-workflow` | `staging.yml` | `production`: workflow file that must have passed on the staging commit (empty to skip) |
| `cliff-config` | | git-cliff config of the release notes (empty for the bundled one) |

## Example

`.github/workflows/pr.yml`:

```yaml
name: PR

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

permissions: {}

concurrency:
  group: pr-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: Test
    if: ${{ !github.event.pull_request.draft }}
    permissions:
      contents: read
    uses: Berack96/workflows/.github/workflows/test.yml@<sha> # vX.Y.Z
    with:
      mise: true
      rust-cache: true
      env: |
        CARGO_TERM_COLOR=always
      run: |
        mise run lint
        mise run test

  security:
    name: Security
    if: ${{ !github.event.pull_request.draft }}
    permissions:
      contents: read
    uses: Berack96/workflows/.github/workflows/security.yml@<sha> # vX.Y.Z
    with:
      python: false
```

`.github/workflows/title.yml`, apart so that editing the title re-runs only this check:

```yaml
name: Title

on:
  pull_request:
    types: [opened, edited, synchronize, reopened, ready_for_review]

permissions: {}

jobs:
  title:
    name: Title
    if: ${{ !github.event.pull_request.draft }}
    uses: Berack96/workflows/.github/workflows/pr-title.yml@<sha> # vX.Y.Z
```

`.github/workflows/security.yml`, every Monday on the default branch:

```yaml
name: Security

on:
  schedule:
    - cron: "0 6 * * 1"

permissions: {}

jobs:
  security:
    name: Security
    permissions:
      contents: read
    uses: Berack96/workflows/.github/workflows/security.yml@<sha> # vX.Y.Z

  issue:
    name: Issue
    needs: security
    if: failure()
    permissions:
      issues: write
    uses: Berack96/workflows/.github/workflows/failure-issue.yml@<sha> # vX.Y.Z
    with:
      title: Weekly security checks failed
```

`.github/workflows/staging.yml`:

```yaml
name: Staging

on:
  push:
    branches: [main]

permissions: {}

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      # ... builds dist/app.zip
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: dist
          path: dist
          retention-days: 1

  release:
    name: Pre-release
    needs: build
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      mode: staging
      staging-prefix: test
      artifact: dist
      assets-notes: Built for linux x86_64.
```

`.github/workflows/production.yml`:

```yaml
name: Production

on:
  workflow_dispatch:
    inputs:
      tag:
        description: Staging tag to release (empty for the latest)
        required: false

permissions: {}

jobs:
  release:
    name: Release
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      mode: production
      staging-prefix: test
      tag: ${{ inputs.tag }}
```

The inputs about tags (`staging`, `staging-prefix`, `staging-scheme`, `release-scheme`, `prerelease`) must be the same
in both modes.

## This repository

The `ci-*.yml` workflows run the workflows above on this repository itself: PR title, security checks (on PRs and
weekly), staging tags on `main` and releases `vX.Y.Z` by hand.

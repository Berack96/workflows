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
| `pattern` | `^(feat\|fix\|perf\|refactor\|docs\|test\|build\|ci\|style\|revert\|chore)(\([^)]+\))?!?: .+` | Bash regex the title must match |

### `test.yml`

Runs the lint and test commands of the caller. Permissions: `contents: read`.

| Input | Default | |
| --- | --- | --- |
| `runs-on` | `ubuntu-latest` | Runner of the job: a label (`windows-latest`, `self-hosted`) or a JSON list (`["self-hosted", "linux"]`). The steps run in bash also on Windows |
| `services` | `{}` | Service containers (a database…), as the JSON of `jobs.<id>.services` |
| `pre-run` | | Commands that prepare the tests, before `run` (bash, one per line) |
| `run` | required | Commands (bash, one per line) |
| `env` | | Environment variables for the whole job, one `NAME=value` per line |
| `mise` | `false` | Install the tools of the repository's mise config (pinned mise) |
| `cache` | | Paths to keep between runs, one per line (`actions/cache`) |
| `cache-key` | | Glob of the files whose hash is the key of the cache, e.g. `**/Cargo.lock`; empty for a new cache each run, restored from the latest |
| `artifact` | | Name of an artifact to upload after the tests, for the next jobs |
| `artifact-path` | | Files of the artifact |

### `security.yml`

Security checks, each one can be turned off (e.g. `python: false` when the Python code does not go to production). The
dependency checks run only when their lockfiles are tracked in the repository; any known vulnerability fails them. The
report, a table of the results with the output of the failed checks, is always in the run summary; on a PR it is also
a comment, created when a check fails and updated by the next runs. Permissions: `contents: read`,
`pull-requests: write`.

| Input | Default | Check |
| --- | --- | --- |
| `secrets` | `true` | Committed secrets (gitleaks) |
| `actions` | `true` | GitHub Actions workflows (zizmor, high severity) |
| `iac` | `true` | Dockerfiles and other infrastructure as code (Trivy, high and critical) |
| `rust` | `true` | Each workspace (the outermost `Cargo.toml`) and each `Cargo.lock`; a library without `Cargo.lock` gets one at the latest versions (cargo-deny: all checks with a `deny.toml`, without it all but licenses) |
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

Tags and GitHub releases of one environment: staging, production, beta, a mod loader, a project of a monorepo… An
environment is the template of its tags, and each call creates tags of one environment:

- without `from` it tags the commit of the run: the pushed one, or the head of the branch when started by hand. A run
  on a commit the branch has already moved past does nothing.
- with `from` it promotes a tag of another environment: same commit, no rebuild, with the files of its GitHub release.
  The tag must be on the branch and after the latest tag of this environment; with `from-workflow`, that workflow must
  have passed on its commit, since anyone with write access can push a tag.

Started by hand, only an admin of the repository can run it. The branch is the one of the run. Re-running a failed run
is safe: tags and releases already created are checked and kept.

#### Tag templates

| Placeholder | Value |
| --- | --- |
| `{X}`, `{Y}`, `{Z}` | Next version after the latest release (`release-tag`): `!` in a commit title bumps X, `feat` Y, anything else Z; `v0.0.0` without releases |
| `{YYYY}`, `{YY}`, `{MM}` | Year, short year and month of the commit, in UTC |
| `{N}`, `{NN}`, `{NNN}`… | Counter from 1 among the tags with the same other values, zero-padded to the number of `N` |

| Template | Tags |
| --- | --- |
| `v{X}.{Y}.{Z}` (default) | `v1.6.3` |
| `staging-{YYYY}.{MM}-build.{NNN}` | `staging-2026.05-build.007` |
| `v{X}.{Y}.{Z}-beta.{N}` | `v1.7.0-beta.2` |
| `v{YY}.{MM}.{N}` | `v26.05.3` |
| `web@{X}.{Y}.{Z}` | `web@1.6.3` |
| `api@{YY}.{MM}-build.{N}` | `api@26.05-build.50` |
| `v{X}.{Y}.{Z}+forge-1.21` | `v1.6.3+forge-1.21` |

A template must give a different tag to each commit: with only dates, add a `{N}`.

A variant of a release, a template other than `release-tag` like `fabric-26.3@{X}.{Y}.{Z}`, on a commit that already
has its release takes the same version: a job creates `v1.5.0`, the next ones `fabric-26.3@1.5.0`, `neoforge-26.3@1.5.0`.
A variant added later starts from the version of the mod, not from `0.0.1`.

#### Projects and dependencies

In a monorepo each project is an environment, with its directories in `path`. With `deps` the ones it depends on are
found from the files of the workspace, without running the build tools:

| `deps` | Packages | Dependencies | Shared files |
| --- | --- | --- | --- |
| `cargo` | `workspace.members` of `Cargo.toml` | `[dependencies]`, `[dev-dependencies]`, `[build-dependencies]`, also of `[target.*]` | `Cargo.toml`, `Cargo.lock`, `rust-toolchain(.toml)`, `.cargo` |
| `gradle` | `include` of `settings.gradle(.kts)`, with their `projectDir` | `project(":x")` and `projects.x` in their `build.gradle(.kts)` | root build and settings files, `gradle.properties`, `gradle`, `buildSrc`, `build-logic` |
| `node` | `workspaces` of `package.json`, `pnpm-workspace.yaml` | `dependencies`, `devDependencies`, `peerDependencies`, `optionalDependencies` | `package.json`, `pnpm-workspace.yaml`, the lockfiles of npm, bun, yarn and pnpm |
| `uv` | `tool.uv.workspace.members` of `pyproject.toml` | `dependencies`, `optional-dependencies`, `dependency-groups` | `pyproject.toml`, `uv.lock`, `.python-version` |

A change in a shared file gives a tag to every project, even if it touches only one of them. Anything else (a
`mise.toml`, a Dockerfile) goes in `path`, or in the output of `paths-command`. The command runs at the root of the
repository, without the token of the job, and its tools must already be there. The log of the run lists all the paths.

#### GitHub releases

`github-release: release` creates a release for each tag, `none` only tags. With `prerelease` there is at most one
pre-release per environment: the one of its latest tag after the latest release (`release-tag`). Each new tag gets a
new pre-release and the older ones are deleted; the runs promoting from it update only its notes. In a chain like
alpha → beta → release, the alpha pre-release left behind by a release goes away at the next alpha run.

Immutable releases work: files are attached only when a release is created, later only title and notes change. A
re-run that finds the release already created does not add its files.

The release notes list the commit titles since the latest release (git-cliff, conventional commits), only of `path`
in a monorepo.

Permissions: `contents: write`, `pull-requests: read`, `actions: read`.

| Input | Default | |
| --- | --- | --- |
| `tag` | `v{X}.{Y}.{Z}` | Template of the tags this run creates |
| `release-tag` | | Template of the release tags, base of `{X}.{Y}.{Z}` and of the notes; empty when this run creates them (only with `github-release: release`) |
| `from` | | Template of the tags to promote; empty to tag the commit of the run |
| `from-tag` | | Tag to promote (empty for the latest of `from` on the branch) |
| `from-workflow` | | Workflow file that must have passed on the commit of the tag to promote |
| `github-release` | `release` | `release`, `prerelease` or `none` |
| `path` | | Directories and files of the project in a monorepo, one per line. Only their commits count for `{X}.{Y}.{Z}` and the notes, and without `from` no tag is created if none came after the latest tag of the environment |
| `deps` | | `cargo`, `gradle`, `node` or `uv`: adds to `path` the workspace packages its projects depend on, and the shared build files |
| `deps-root` | `.` | Directory of the workspace that `deps` reads, e.g. `native` |
| `paths-command` | | Command (bash) whose output, one per line, is added to `path`: for the dependencies `deps` cannot find |
| `artifact` | | Artifacts whose files are attached to the GitHub release (without `from`): a name, or a glob like `build-*` for the ones of a matrix (files with the same name overwrite each other) |
| `assets-notes` | | Text added to the release notes when there are attached files |
| `cliff-config` | | git-cliff config of the release notes (empty for the bundled one) |
| `dry-run` | `false` | Only compute the tag, without creating tags and releases: for a build that needs its version |
| `expect-tag` | | Tag the run must create, the one of the dry run: it fails if another tag came in between |

| Output | |
| --- | --- |
| `tag` | Tag of the run, empty when the branch has moved past the commit |
| `sha` | Commit of the tag |

Tags created with the `GITHUB_TOKEN` do not start other workflows (`on: push: tags`): a deploy is a job after the
release, with `needs` and `needs.<job>.outputs.tag`.

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
      cache: |
        ~/.cargo/registry
        ~/.cargo/git
        target
      cache-key: "**/Cargo.lock"
      env: |
        CARGO_TERM_COLOR=always
      pre-run: |
        mise run setup
      run: |
        mise run lint
        mise run test

  security:
    name: Security
    if: ${{ !github.event.pull_request.draft }}
    permissions:
      contents: read
      pull-requests: write
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
      pull-requests: write
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
      tag: test-{YY}.{MM}-build.{NNN}
      release-tag: v{X}.{Y}.{Z}
      github-release: prerelease
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
      from: test-{YY}.{MM}-build.{NNN}
      from-tag: ${{ inputs.tag }}
      from-workflow: staging.yml
```

A build that needs its version (in the jar, in `Cargo.toml`): a dry run gives the tag, the build uses it, the release
creates it and checks it is still the same. With `path`, an empty tag means nothing changed:

```yaml
jobs:
  version:
    name: Version
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      dry-run: true

  build:
    name: Build
    needs: version
    if: needs.version.outputs.tag != ''
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    permissions:
      contents: read
    steps:
      # ... builds dist/ with the version of ${{ needs.version.outputs.tag }}
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: build-${{ matrix.os }}
          path: dist
          retention-days: 1

  release:
    name: Release
    needs: [version, build]
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      expect-tag: ${{ needs.version.outputs.tag }}
      artifact: build-*
```

A single release for the whole repository, by hand, without staging:

```yaml
on:
  workflow_dispatch:

jobs:
  release:
    name: Release
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z

  deploy:
    name: Deploy
    needs: release
    if: needs.release.outputs.tag != ''
    runs-on: self-hosted
    steps:
      - run: echo "deploy ${{ needs.release.outputs.tag }}"
```

A Minecraft mod built for several loaders from the same commit: the version of the mod, then one release per loader
with the same version:

```yaml
jobs:
  version:
    name: Version
    needs: build
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      # Only the tag: the releases are the ones of the loaders.
      release-tag: v{X}.{Y}.{Z}
      github-release: none

  release:
    name: Release
    needs: version
    strategy:
      matrix:
        loader: [fabric-26.3, neoforge-26.3]
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      tag: ${{ matrix.loader }}@{X}.{Y}.{Z}
      release-tag: v{X}.{Y}.{Z}
      artifact: ${{ matrix.loader }}
```

A monorepo, one environment per project, with the dependencies from Gradle: a change in `common` gives a staging tag
to both loaders, a change in `fabric` only to Fabric:

```yaml
on:
  push:
    branches: [main]

jobs:
  staging:
    name: Pre-release
    strategy:
      matrix:
        loader: [fabric, neoforge]
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      tag: ${{ matrix.loader }}-staging-{YYYY}.{MM}-build.{NNN}
      release-tag: ${{ matrix.loader }}@{X}.{Y}.{Z}
      github-release: prerelease
      path: |
        ${{ matrix.loader }}
        mise.toml
      deps: gradle
```

## This repository

The `ci-*.yml` workflows run the workflows above on this repository itself: PR title, security checks (on PRs and
weekly), staging tags on `main` and releases `vX.Y.Z` by hand.

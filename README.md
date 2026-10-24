# workflows

My personal GitHub workflows: reusable workflows (`workflow_call`) for PR titles, tests, security checks, security
fixes and releases, generic enough for any repository.

- [Usage](#usage)
- [`pr-title.yml`](#pr-titleyml): format of the PR titles
- [`test.yml`](#testyml): lint and tests
- [`security.yml`](#securityyml): security checks
- [`security-fix.yml`](#security-fixyml): draft PR with the fixes of failed security checks
- [`release.yml`](#releaseyml): tags and GitHub releases
- [Examples](#examples)

## Usage

A job calls a workflow with `uses`, pinned to a commit with its version in a comment, and grants it the permissions it
needs (listed for each workflow):

```yaml
jobs:
  title:
    uses: Berack96/workflows/.github/workflows/pr-title.yml@<sha> # vX.Y.Z
```

The workflows contain all their scripts: nothing is loaded from this repository at another ref, so the pinned commit
is all that runs. Inputs with several values (commands, paths) take one per line.

Settings of the repositories:

- **This repository private**: only the private repositories of the same owner can call it, with **Settings → Actions
  → General → Access → Accessible from repositories owned by the user**. A public repository can call it only if this
  one is public.
- **`security-fix.yml`**: **Settings → Actions → General → Allow GitHub Actions to create and approve pull requests**
  in the calling repository.
- **Immutable releases** (**Settings → General → Releases**) work with `release.yml`.

## `pr-title.yml`

Checks the title of a PR, which becomes the subject of the squash commit and decides the next version in
`release.yml`. Permissions: none.

| Input | Default | |
| --- | --- | --- |
| `pattern` | `^(feat\|fix\|perf\|refactor\|docs\|test\|build\|ci\|style\|revert\|chore)(\([^)]+\))?!?: .+` | Bash regex the title must match |

A separate workflow from the tests, with the `edited` event: editing the title re-runs only this check.

## `test.yml`

Runs the lint and test commands of the caller, after preparing tools and cache. The steps run in bash on every system,
Windows included. Permissions: `contents: read`.

| Input | Default | |
| --- | --- | --- |
| `run` | required | Commands of lint and tests (bash) |
| `pre-run` | | Commands that prepare the tests, before `run`, in a step of their own (bash) |
| `runs-on` | `ubuntu-latest` | Runner: a label (`windows-latest`, `self-hosted`) or a JSON list (`["self-hosted", "linux"]`) |
| `services` | `{}` | Service containers (a database…), as the JSON of [`jobs.<id>.services`](https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idservices) |
| `env` | | Environment variables of the whole job, `NAME=value`; set before mise, so they can configure it (`MISE_DISABLE_TOOLS`) |
| `mise` | `false` | Install the tools of the repository's mise config; mise is pinned by version, and by sha256 on linux-x64 |
| `cache` | | Paths kept between runs (`actions/cache`), one cache per system and architecture |
| `cache-key` | | Glob of the files whose hash is the key of the cache, e.g. `**/Cargo.lock`; empty for a new cache each run, restored from the latest |
| `artifact` | | Name of an artifact uploaded after the tests, for the next jobs (kept one day) |
| `artifact-path` | | Files of the artifact |

A database for the tests:

```yaml
    with:
      services: |
        {"postgres": {"image": "postgres:18-alpine", "ports": ["5432:5432"],
          "env": {"POSTGRES_USER": "test", "POSTGRES_PASSWORD": "test"},
          "options": "--health-cmd pg_isready --health-interval 5s --health-retries 10"}}
```

## `security.yml`

Security checks: each one can be turned off, e.g. `python: false` when the Python code does not go to production. The
dependency checks run only for the ecosystems tracked in the repository, and any known vulnerability fails them. All
the checks run even after a failed one. Permissions: `contents: read`, `pull-requests: write`.

| Input | Default | Check |
| --- | --- | --- |
| `secrets` | `true` | Committed secrets, in the files of the commit (gitleaks) |
| `actions` | `true` | GitHub Actions workflows (zizmor, high severity) |
| `iac` | `true` | Dockerfiles and other infrastructure as code (Trivy, high and critical) |
| `rust` | `true` | Each workspace (the outermost `Cargo.toml`) and each `Cargo.lock` (cargo-deny: all its checks with a `deny.toml`, without it all but the licenses). A library without `Cargo.lock` gets one at the latest versions |
| `python` | `true` | `uv.lock`, `poetry.lock`, `Pipfile.lock`, `pdm.lock`, `requirements.txt` (OSV-Scanner) |
| `javascript` | `true` | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lock` (OSV-Scanner) |
| `java` | `true` | `pom.xml`, `gradle.lockfile` (OSV-Scanner; Gradle needs dependency locking) |
| `go` | `true` | `go.mod` (OSV-Scanner) |

The report, a table of the results with the output of the failed checks, is always in the run summary. On a PR it is
also a comment: created when a check fails, then updated by the next runs, also when they pass. From a fork the token
cannot comment, and the report stays in the summary.

## `security-fix.yml`

After failed security checks (`needs` on the job of `security.yml`, `if: failure()`): a draft PR with a single commit on
top of the branch of the run, always on the same branch, so the PR is updated and never opened twice.
Permissions: `contents: write`, `pull-requests: write`.

1. OSV-Scanner finds the vulnerable packages of all the lockfiles (`.gitignore` is respected).
2. The ones of the built-in ecosystems are updated, only them and as far as the version ranges of the manifests allow.
   A failed update does not stop the others.
3. `update-command` runs, for everything else.
4. A second scan tells which ones are fixed. The PR lists all of them, with links to their advisories.

| Lockfile | Update |
| --- | --- |
| `Cargo.lock` | `cargo update -p <name>@<version>` |
| `package-lock.json` | `npm update --package-lock-only --ignore-scripts <name>` |
| `bun.lock` | `bun update --ignore-scripts <name>` |
| `pnpm-lock.yaml` | `pnpm update --lockfile-only --ignore-scripts <name>` |
| `uv.lock` | `uv lock --upgrade-package <name>` |

| Input | Default | |
| --- | --- | --- |
| `branch` | `fix/security` | Branch of the PR |
| `update-command` | | Command (bash) for the other ecosystems, after the built-in updates. `$VULNERABLE` is a file with a `<lockfile> <name> <version> <advisories>` line per vulnerable package; the files it changes go in the commit |
| `mise` | `false` | Install the tools of the repository's mise config, for `update-command` |

If nothing changed (a committed secret, a vulnerability without a fix) the commit is empty and the PR reports the
failure, with the link to the run. The branch is pushed only when its content changes. A PR already marked ready for
review is left alone: a push made with the token of the workflow would not re-run its CI, which starts when the PR is
marked ready. The updates and `update-command` run without the token.

## `release.yml`

Tags and GitHub releases of one **environment**: staging, production, beta, a mod loader, a project of a monorepo… An
environment is the template of its tags, and each call creates the tags of one environment:

- without `from` it tags the commit of the run: the pushed one, or the head of the branch when started by hand. A run
  on a commit the branch has already moved past does nothing.
- with `from` it promotes a tag of another environment: same commit, no rebuild, with the files of its GitHub release.
  The tag must be on the branch and after the latest tag of this environment; with `from-workflow`, that workflow must
  have passed on its commit, since anyone with write access can push a tag.

Without `path` the tags are of the whole repository. Started by hand, only an admin of the repository can run it. The
branch is the one of the run. Re-running a failed run is safe: tags and releases already created are checked and kept.
Permissions: `contents: write`, `pull-requests: read`, `actions: read`.

| Input | Default | |
| --- | --- | --- |
| `tag` | `v{X}.{Y}.{Z}` | [Template](#tag-templates) of the tags this run creates |
| `release-tag` | | Template of the release tags, base of `{X}.{Y}.{Z}` and of the notes; empty when this run creates them (only with `github-release: release`) |
| `from` | | Template of the tags to promote; empty to tag the commit of the run |
| `from-tag` | | Tag to promote; empty for the latest of `from` on the branch |
| `from-workflow` | | Workflow file (`staging.yml`) that must have passed on the commit of the tag to promote, up to its job calling this workflow |
| `github-release` | `release` | [GitHub release](#github-releases) of the tags: `release`, `prerelease` or `none` |
| `path` | | [Directories and files of the project](#projects-and-dependencies) in a monorepo |
| `deps` | | `cargo`, `gradle`, `node` or `uv`: adds to `path` the workspace packages its projects depend on, and the shared build files |
| `deps-root` | `.` | Directory of the workspace that `deps` reads, e.g. `native` |
| `paths-command` | | Command (bash) whose output, one path per line, is added to `path`: for the dependencies `deps` cannot find |
| `artifact` | | Artifacts whose files are attached to the GitHub release (without `from`): a name, or a glob like `build-*` for the ones of a matrix; files with the same name overwrite each other |
| `assets-notes` | | Text added to the release notes when there are attached files |
| `cliff-config` | | git-cliff config of the release notes, a path in the repository; empty for the bundled one |
| `dry-run` | `false` | Only compute the tag, in the `tag` output, without creating tags and releases: for a build that needs its version |
| `expect-tag` | | Tag the run must create, the one of the dry run: it fails if another tag came in between |

| Output | |
| --- | --- |
| `tag` | Tag of the run; empty when there is none: the branch has moved past the commit, or nothing changed in `path` |
| `sha` | Commit of the tag |

Tags created with the `GITHUB_TOKEN` do not start other workflows (`on: push: tags`, `on: release`): a build or a
deploy is a job before or after the release, with `needs` and its outputs.

### Tag templates

| Placeholder | Value |
| --- | --- |
| `{X}`, `{Y}`, `{Z}` | Next version after the latest release (`release-tag`), from the titles of the commits after it (of `path` only): `!` bumps X, `feat` Y, anything else Z; from `0.0.0` without releases |
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
| `fabric-26.3@{X}.{Y}.{Z}` | `fabric-26.3@1.6.3` |

A template must give a different tag to each commit: with only dates, add a `{N}`.

**Variants.** A template other than `release-tag`, like `fabric-26.3@{X}.{Y}.{Z}` with `release-tag: v{X}.{Y}.{Z}`,
on a commit that already has its release takes the same version: a job creates `v1.5.0`, the next ones
`fabric-26.3@1.5.0` and `neoforge-26.3@1.5.0`. A variant added later starts from the current version, not from
`0.0.1`. With `path`, a variant whose files did not change gets no tag: one numbering, and a release only for the
variants that changed.

### Projects and dependencies

In a monorepo each project is an environment, with its directories and files in `path`. Only their commits count for
`{X}.{Y}.{Z}` and the notes, and without `from` no tag is created if none came after the latest tag of the
environment. With `deps` the packages it depends on are found from the files of the workspace, without running the
build tools:

| `deps` | Packages | Dependencies | Shared files |
| --- | --- | --- | --- |
| `cargo` | `workspace.members` of `Cargo.toml` | `[dependencies]`, `[dev-dependencies]`, `[build-dependencies]`, also of `[target.*]` | `Cargo.toml`, `Cargo.lock`, `rust-toolchain(.toml)`, `.cargo` |
| `gradle` | `include` of `settings.gradle(.kts)`, with their `projectDir` | `project(":x")` and `projects.x` in their `build.gradle(.kts)` | root build and settings files, `gradle.properties`, `gradle`, `buildSrc`, `build-logic` |
| `node` | `workspaces` of `package.json`, `pnpm-workspace.yaml` | `dependencies`, `devDependencies`, `peerDependencies`, `optionalDependencies` | `package.json`, `pnpm-workspace.yaml`, the lockfiles of npm, bun, yarn and pnpm |
| `uv` | `tool.uv.workspace.members` of `pyproject.toml` | `dependencies`, `optional-dependencies`, `dependency-groups` | `pyproject.toml`, `uv.lock`, `.python-version` |

The dependencies of the dependencies count too. A change in a shared file gives a tag to every project, even if it
touches only one of them. Anything else (a `mise.toml`, a Dockerfile) goes in `path`, or in the output of
`paths-command`: it runs at the root of the repository, without the token of the job, and its tools must already be
there. The log of the run lists all the paths.

### GitHub releases

`github-release: release` creates a release for each tag, `none` only tags. With `prerelease` there is at most one
pre-release per environment: the one of its latest tag after the latest release (`release-tag`). Each new tag gets a
new pre-release and the older ones are deleted; the runs promoting from it update only its notes. In a chain like
alpha → beta → release, the alpha pre-release left behind by a release goes away at the next alpha run.

Files are attached only when a release is created, later only title and notes change: immutable releases work. A
re-run that finds the release already created does not add its files. A promoted tag gets the files of its
pre-release, if it is still there: only the latest tag of an environment has one.

The release notes list the titles of the commits since the latest release, of `path` only in a monorepo (git-cliff,
conventional commits): Features (`feat`), Fixes (`fix`) and the others in a collapsed section, with the scope in bold,
the link to the full changelog and the authors.

## Examples

### PR: tests and security checks

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

### PR title

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

### Weekly security checks, with the fixes

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

  fix:
    name: Fix
    needs: security
    if: failure()
    permissions:
      contents: write
      pull-requests: write
    uses: Berack96/workflows/.github/workflows/security-fix.yml@<sha> # vX.Y.Z
    with:
      # Go is not built in.
      update-command: |
        grep '^go.mod ' "$VULNERABLE" | while read -r _ name _; do go get "$name@latest"; done
        go mod tidy
```

### Staging on each push, production by hand

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
      tag: staging-{YY}.{MM}-build.{NNN}
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
      from: staging-{YY}.{MM}-build.{NNN}
      from-tag: ${{ inputs.tag }}
      from-workflow: staging.yml
```

### Only production, by hand, then a deploy

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

### A build that needs its version, on several systems

A dry run gives the tag, the build uses it (in the jar, in `Cargo.toml`), the release creates it and checks it is
still the same:

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

### A monorepo: one environment per project

A staging tag for each project that changed, with the dependencies from Gradle: a change in `common` gives one to both
loaders, a change in `fabric` only to Fabric:

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

### Variants with one numbering: a mod for several loaders

The version of the mod for the whole repository, then a release for each loader that changed, with that same
version: `v1.5.0`, `fabric-26.3@1.5.0`, and `neoforge-26.3@1.5.0` only if NeoForge or `common` changed:

```yaml
on:
  workflow_dispatch:

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
    strategy:
      matrix:
        loader: [fabric, neoforge]
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      # ... builds dist/ with the version of ${{ needs.version.outputs.tag }}
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: ${{ matrix.loader }}
          path: dist
          retention-days: 1

  # Only the tag of the mod: the releases are the ones of the loaders.
  tag:
    name: Tag
    needs: [version, build]
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      release-tag: v{X}.{Y}.{Z}
      github-release: none
      expect-tag: ${{ needs.version.outputs.tag }}

  release:
    name: Release
    needs: tag
    strategy:
      matrix:
        loader: [fabric, neoforge]
    permissions:
      contents: write
      pull-requests: read
      actions: read
    uses: Berack96/workflows/.github/workflows/release.yml@<sha> # vX.Y.Z
    with:
      tag: ${{ matrix.loader }}-26.3@{X}.{Y}.{Z}
      release-tag: v{X}.{Y}.{Z}
      path: ${{ matrix.loader }}
      deps: gradle
      artifact: ${{ matrix.loader }}
```

## This repository

The `ci-*.yml` workflows run the workflows above on this repository itself: PR title, security checks (on PRs, and
weekly with the fixes), staging tags on `main` and releases `vX.Y.Z` by hand.

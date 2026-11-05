# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language

Everything is **in English**: code, comments, README, commit messages, titles and descriptions of PRs and issues, and replies to the user. Keep this convention in everything you write.

## How to work in this repo

**Rule number one: touch nothing that was not asked for.** The rest of this section follows from it.

- **Closed scope**: change only the files and lines needed for the request. Do not rewrite working code, rename, reorder imports, reformat lines you are not already changing, add docstrings/comments/type hints to unrelated code, or "fix" nearby files. A file the task does not need stays as it is.
- **Short comments**: if a comment is really needed (it explains a non-obvious why), at most 1-2 lines. No long comment blocks. No references to issues, PRs, tasks or the history of the change ("issue #NN", "added for...", "it used to be..., now..."): a comment describes the current state of the code, not how it got there — those references rot as soon as the code changes again and belong in the commit message or the PR, not in the code. No file paths in comments: name the thing (function, type, command), not the file it is in, which moves.
- **Bare minimum**: of what was asked, implement the smallest version that works; bugs found along the way are reported at the end, not fixed on your own initiative. Before calling it done, self-check the diff with the `minimal-code` skill.
- **Do not be minimal on**: input validation at trust boundaries, error handling that prevents data loss, security measures, basic accessibility, anything explicitly asked for.
- **Autonomy**: go ahead with code changes without asking for confirmation; ask only if two readings of the task lead to substantially different work.
- **Git**: do not commit or push unless explicitly asked. The main branch is `main` and work happens on dedicated branches merged through PRs. Commits and PR titles follow Conventional Commits: types `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`; the scope, mandatory in PR titles, is the name of the workflow touched without extension (`pr-title`, `test`, `security`, `security-fix`, `release`, `deploy`), `settings`, or `claude` for `.claude/`.

### When a new feature is requested

When work with commits is explicitly requested (a feature, a fix, or other work in several steps — the **Git** bullet above still holds: only if asked), the flow — branch, checklist, draft PR, one commit per step, handling requests that widen the work, pre-ready review, PR ready for review — is in the `pr` skill; for the format of single commits see the `commit` skill.

## Project documentation

The [README.md](../README.md) at the root is the only documentation of the repository: inputs, permissions and behavior of each reusable workflow, settings of the calling repositories, examples. When you need to understand *what* a workflow does or *why*, read the README (and the workflow), not this file.

This CLAUDE.md is only an operational map: where things are, how they run, which constraints to respect.

## Maintenance of this file

**By default this file is NOT touched**: it is not a changelog. When and how to update it (and when the README should be updated instead) is in the `documentation` skill.

## Commands

```bash
settings/apply.sh <owner>/<repo>  # applies the GitHub settings of settings/ to a repository (gh and jq, as admin)
```

**Tests**: there are no local tests. On PRs the `ci-*.yml` workflows run, calling the reusable workflows of this same repository (title, security checks with zizmor); behavior changes are tested with real runs on a temporary branch. Do not invent test commands beyond these.

## Architecture

- `.github/workflows/<name>.yml` without prefix: the reusable workflows (`workflow_call`), used by other repositories with a `vX.Y.Z` tag. They contain all their scripts: they load nothing from this repository at another ref.
- `.github/workflows/ci-*.yml`: the CI of this repository, calling the reusable workflows with `./`.
- `settings/`: GitHub settings and ruleset the workflows expect in the calling repositories.
- The PR title becomes the subject of the squash commit and decides the next version (`feat` → minor, `!` → major, anything else → patch): a push on `main` creates a staging tag (not for `.md` files and `.claude/`), the `vX.Y.Z` release is immutable.

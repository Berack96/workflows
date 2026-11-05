---
name: pr
description: Handles the full flow of a feature/fix with commits in this repository, from creating the branch to the pull request ready for review. Use it when work with commits is explicitly requested.
---

This skill applies only if work with commits was explicitly requested — do not open branches, commit or open PRs on your own initiative.

1. **Branch**: create a branch from `origin/main` (or from the starting branch, if different) with a name that reflects what the feature/fix does.
2. **Checklist and first commit**: define the checklist of the items to implement, do the first one and make a dedicated commit, then push the branch — at least one commit of difference from the base is needed, GitHub does not allow a PR between two identical branches. Each commit is made by invoking the `commit` skill (Skill tool), never with a direct `git commit`.
3. **Draft PR**: open the PR right away as **draft**, from the branch to the starting branch.
   - Title: Conventional Commits with mandatory scope, short, in English; allowed types and scopes are in the Git section of `CLAUDE.md`.
     The title becomes a line of the release notes, read by people who did not follow the work:
     - it says the effect, i.e. what the project does now or what changes for its users, not the pieces touched: modules, files and libraries only if they are the subject of the change (`feat(ci): more readable release notes, with the link to the PR of each change`, not `feat(ci): emoji, PR links and a single list in cliff.toml`);
     - one change only, no lists with "and": if two are needed, the title says the main one and the rest goes in the description, or there should have been two PRs;
     - at most about 60 characters after the scope, without terms born during the work (names of discarded options, numbers of steps or PRs).
   - Body, in English: **Summary** (2-3 lines, the current state of the PR, not the history of how it got there); if the work comes from an issue (or you are asked to link one), a line on its own with the closing keyword (e.g. `Closes #<number>`) — never just a textual mention — and only if the starting branch of this PR is the default branch of the repository (otherwise the issue does not close by itself on merge: say so explicitly in that case); **Changes**, the full checklist with the first item already checked; **Note** (optional) for things explicitly left out of scope.
4. **Implementation**: implement the remaining checklist items one at a time (even halfway, if it makes sense to split them): a dedicated commit for each, with the `commit` skill, and the check in the PR description.
5. **Requests that widen the work**: if during the work a request comes to change the feature or add something — a small deviation from what is in progress → implement it in the same PR; a real refactor or something too far from the work in progress → ask how to proceed instead of deciding alone. When the change goes into the PR, update the description so it reflects the current state, not the path to get there (no "first it was like this, then we added...").
6. **Pre-ready review**: before marking the PR ready, delegate the review to the `reviewer` subagent (Sonnet, effort high), passing it only the base branch (and the repository folder, if not the current one) — never in-process: whoever wrote the changes already has the context and risks missing bugs, duplication, typos or logic problems a fresh reader would find. Fix small findings in the PR itself; for large ones ask how to proceed.
7. **Ready**: remove references to the future ("will be done"...) from the description and mark the PR ready for review (remove the draft state).

If the platform requires an attribution footer in the PR body, add it at the end.

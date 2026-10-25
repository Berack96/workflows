#!/usr/bin/env bash
# Settings of a repository that calls these workflows, with `gh` logged in as an admin of it: squash merge with the PR
# title, immutable releases, PRs by GitHub Actions, and the ruleset of the default branch. Run it again to align a
# repository: the ruleset with the same name is updated, not created twice.
#
#   settings/apply.sh <owner>/<repo> [ruleset.json]
set -euo pipefail

repo=${1:?usage: $0 <owner>/<repo> [ruleset.json]}
dir=$(dirname "$0")
ruleset=${2:-$dir/ruleset.json}

gh api -X PATCH "repos/$repo" --input "$dir/settings.json" > /dev/null
gh api -X PUT "repos/$repo/immutable-releases" > /dev/null
gh api -X PUT "repos/$repo/actions/permissions/workflow" -F can_approve_pull_request_reviews=true > /dev/null

name=$(jq -r .name "$ruleset")
id=$(gh api "repos/$repo/rulesets" --paginate --jq ".[] | select(.name == \"$name\") | .id" | head -n 1)
if [ -n "$id" ]; then
  gh api -X PUT "repos/$repo/rulesets/$id" --input "$ruleset" > /dev/null
else
  gh api -X POST "repos/$repo/rulesets" --input "$ruleset" > /dev/null
fi
echo "$repo: settings and ruleset \"$name\" applied"

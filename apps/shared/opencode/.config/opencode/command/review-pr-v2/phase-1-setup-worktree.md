# Phase 1: Determine PR and Setup Environment

## Parse Command Arguments

Check if user provided a PR URL argument:
```bash
pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
use_worktree=true
echo "Using provided PR URL: $pr_url"
```

If no PR URL provided:
```bash
# Auto-detect PR for current branch
pr_data=$(gh pr view --json url,number -q '{url: .url, number: .number}' 2>&1)

if echo "$pr_data" | grep -q "no pull requests found"; then
  echo "Error: No PR found for current branch"
  echo ""
  echo "Please either:"
  echo "  1. Provide a PR URL: /git:review-pr-v2 https://github.com/owner/repo/pull/123"
  echo "  2. Create a PR for this branch: gh pr create"
  exit 1
fi

pr_url=$(echo "$pr_data" | jq -r .url)
pr_number=$(echo "$pr_data" | jq -r .number)
use_worktree=false
echo "Auto-detected PR for current branch: $pr_url"
```

## Setup Worktree (if needed)

When reviewing a PR from a URL (not current branch), create a worktree to avoid disrupting user's work:

```bash
if [ "$use_worktree" = true ]; then
  # Get PR metadata including base branch
  pr_info=$(gh pr view $pr_number --json headRefName,baseRefName)
  pr_branch=$(echo "$pr_info" | jq -r .headRefName)
  base_branch=$(echo "$pr_info" | jq -r .baseRefName)
  
  # Get git repository root
  repo_root=$(git rev-parse --show-toplevel)
  worktree_dir="${repo_root}/.worktree/pr-review-${pr_number}"
  
  # Create .worktree directory
  mkdir -p "${repo_root}/.worktree"
  
  # Fetch latest from remote (avoid stale state)
  echo "Fetching latest changes from origin/$pr_branch"
  git fetch origin "$pr_branch"
  
  # Create worktree from remote branch (ensures latest commit)
  git worktree add "$worktree_dir" "origin/$pr_branch"
  
  # Change to worktree directory
  cd "$worktree_dir"
  
  echo "Created worktree at $worktree_dir"
  echo "Current commit: $(git log -1 --oneline)"
  echo "Base branch: $base_branch"
else
  # Using current branch - get base branch for context
  base_branch=$(gh pr view $pr_number --json baseRefName -q .baseRefName)
  echo "Reviewing current branch (no worktree needed)"
  echo "Base branch: $base_branch"
fi
```

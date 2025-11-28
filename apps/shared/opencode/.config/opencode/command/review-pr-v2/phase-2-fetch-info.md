# Phase 2: Fetch PR Information

Now that we have `$pr_number` and `$base_branch` from Phase 1, fetch all PR data:

```bash
# Get repository info for GraphQL API calls
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
owner=$(echo "$repo_info" | cut -d'/' -f1)
repo=$(echo "$repo_info" | cut -d'/' -f2)

# Fetch all PR information in one go
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== BASE_BRANCH ===" && echo "$base_branch" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== REVIEW_THREADS_AND_HISTORY ===" && gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            comments(first: 10) {
              nodes {
                databaseId
                author { login }
                body
                path
                line
              }
            }
          }
        }
        reviews(last: 100, states: COMMENTED) {
          nodes {
            body
            commit { oid }
            createdAt
          }
        }
      }
    }
  }' -f owner="$owner" -f repo="$repo" -F pr=$pr_number && \
echo "=== CURRENT_COMMIT ===" && git rev-parse HEAD && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- Worktree created from `origin/$branch` (not local branch) to ensure latest state
- Single chained command for efficiency
- Captures PR description AND base branch for context
- **Fetches review threads with resolution status** using GraphQL for re-review detection
- **Fetches review history with commit SHAs** for incremental review detection
- **Captures current commit** to compare against last review
- Uses correct repo info format for API calls

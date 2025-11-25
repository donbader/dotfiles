---
name: git:review-pr
description: Provide comprehensive, educational code review for GitHub PRs
---

# Review GitHub Pull Request

Perform thorough, educational code reviews that help developers learn and improve code quality through constructive feedback.

## Usage

```bash
# Review specific PR by URL
/git:review-pr https://github.com/owner/repo/pull/123

# Review PR for current branch (auto-detect)
/git:review-pr
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

### Re-Review Mode

When previous OpenCode review comments exist, automatically switches to re-review mode:
- Fetches all existing review threads and verifies current state
- For each unresolved thread: Verifies fix, replies in-thread, marks resolved if addressed
- Reviews new/changed code for additional issues
- Posts in-thread comments only (never standalone)
- Posts verification summary comment when all concerns addressed
- **Never directly approves** - leaves approval decision to the reviewer

## Workflow Overview

### First Review
1. **Setup**: Create worktree (if URL provided) or use current branch
2. **Fetch**: Get PR metadata, diff, and changed files
3. **Analyze**: Review code changes for issues (security, performance, architecture, testing, readability)
4. **Present**: Show proposed comments to user for approval
5. **Post**: Submit review to GitHub as single request with inline comments
6. **Cleanup**: Remove worktree if created

### Re-Review (Autonomous Verification)
1. **Detect**: Identify previous OpenCode review threads
2. **Verify**: For each unresolved thread, check if issue is fixed
3. **Reply**: Post in-thread verification (resolved/not resolved)
4. **Mark**: Resolve threads that are fixed using GraphQL API
5. **Scan**: Review new/changed code for additional issues
6. **Summarize**: Post verification summary if all concerns addressed
7. **Cleanup**: Remove worktree if created

**Verification summary criteria**: 
- ✅ All previous issues verified fixed and resolved
- ✅ No new issues in recent changes
- ➡️ Post standalone comment indicating PR is ready for human approval

## Review Philosophy

Every review should be a learning opportunity that improves developer skills.

**Core characteristics**:
- **Educational**: Explain WHY changes are needed, not just WHAT
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact files, line numbers, and code patterns
- **Balanced**: Acknowledge strengths AND identify improvements
- **Actionable**: Provide clear, implementable next steps
- **Focused**: Comment only on code within PR scope
- **Context-aware**: Understand PR intent from description

## Core Principles

### 1. Stay Within Scope

**Inline comments** - Only for code changes in this PR:
- Security vulnerabilities, bugs, breaking changes
- Performance problems in modified code
- Architecture violations in changed code
- Missing tests for new functionality
- Readability issues in changed code

**Summary section** - For broader suggestions:
- Refactoring opportunities outside PR scope
- Future architecture improvements
- Technical debt to track separately
- Clearly marked as non-blockers

**Examples**:
```
❌ BAD: "UserService should use dependency injection"
   (UserService not modified - creates scope creep)

✅ GOOD: "getUserProfile() queries DB directly. Use existing 
   UserRepository pattern (see getUserById:42) for consistency"
   (getUserProfile() is new - directly relevant)

✅ SUMMARY: "Future: UserService could benefit from dependency 
   injection for testability (not blocking this OAuth PR)"
```

### 2. Understand PR Context

Always read the PR description to understand:
- **What**: Author's stated goal and changes
- **Why**: Motivation and problem being solved
- **Scope**: Feature, bug fix, hotfix, or refactor
- **Constraints**: Known trade-offs or limitations
- **Testing**: Author's testing approach

This prevents commenting on intentional decisions or asking already-answered questions.

**Context-aware examples**:
```
"Quick hotfix for production bug - will refactor in JIRA-123"
→ Focus on correctness over perfect architecture

"Part 1 of 3: Data layer only, UI in next PR"  
→ Don't comment on missing UI

"Using polling due to firewall restrictions"
→ Don't suggest webhooks as alternative
```

## Workflow

### Phase 1: Setup Worktree (if needed)

**IMPORTANT**: When reviewing a PR from a URL (not current branch), use git worktree to avoid disrupting user's work.

**CRITICAL**: Always create worktree from `origin/$branch` to ensure latest remote state, not stale local references.

```bash
# Determine if we need a worktree
if [ -n "$1" ]; then
  # PR URL provided - extract PR number
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  use_worktree=true
  echo "=== Using PR from URL - will create worktree ==="
else
  # Use current branch
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
  use_worktree=false
fi

if [ -z "$pr_number" ]; then 
  echo "ERROR: No PR found. Provide URL or ensure current branch has a PR."
  exit 1
fi

# Setup worktree if needed
if [ "$use_worktree" = true ]; then
  # Get PR metadata including base branch (don't assume main/master)
  pr_info=$(gh pr view $pr_number --json headRefName,baseRefName)
  pr_branch=$(echo "$pr_info" | jq -r .headRefName)
  base_branch=$(echo "$pr_info" | jq -r .baseRefName)
  
  # Get git repository root and create worktree directory
  repo_root=$(git rev-parse --show-toplevel)
  worktree_dir="${repo_root}/.worktree/pr-review-${pr_number}"
  
  # Create .worktree directory if it doesn't exist
  mkdir -p "${repo_root}/.worktree"
  
  # CRITICAL: Fetch latest from remote to avoid stale state
  echo "=== Fetching latest changes from origin/$pr_branch ==="
  git fetch origin "$pr_branch"
  
  # Create worktree from remote branch reference (not local)
  # This ensures we get the absolute latest commit from remote
  git worktree add "$worktree_dir" "origin/$pr_branch"
  
  # Change to worktree directory
  cd "$worktree_dir"
  
  # Verify we're on the latest commit
  latest_commit=$(git log -1 --oneline)
  echo "=== Created worktree at $worktree_dir ==="
  echo "=== Current commit: $latest_commit ==="
  echo "=== Base branch: $base_branch ==="
  
  # Sanity check: verify no newer commits on remote
  git fetch origin "$pr_branch" 2>/dev/null
  newer_commits=$(git log HEAD..origin/$pr_branch --oneline)
  if [ -n "$newer_commits" ]; then
    echo "⚠️  WARNING: Remote has newer commits than worktree!"
    echo "$newer_commits"
    echo "=== Resetting to latest remote commit ==="
    git reset --hard "origin/$pr_branch"
  fi
fi
```

### Phase 2: Fetch PR Information

**Single bash command** to fetch all required data:

```bash
# Get repository info for API calls
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Fetch all PR information in one go
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== BASE_BRANCH ===" && echo "$base_branch" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== REVIEW_THREADS ===" && gh api "repos/${repo_info}/pulls/${pr_number}/comments" --jq '[.[] | select(.body | contains("🤖 Generated by OpenCode") or .body | contains("🤖 Re-verified by OpenCode")) | {id, path, line, created_at, body, in_reply_to_id}]' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- Worktree created from `origin/$branch` (not local branch) to ensure latest state
- Single chained command for efficiency
- Captures PR description AND base branch for context
- **Fetches all review threads** (not just top-level comments) with full details for re-review
- Uses correct repo info format for API calls

## Implementation Workflow

### Phase 1: Setup Worktree (if needed)

When reviewing a PR from URL (not current branch), use git worktree to avoid disrupting user's work.

**CRITICAL**: Always create worktree from `origin/$branch` to ensure latest remote state.

```bash
# Determine if we need a worktree
if [ -n "$1" ]; then
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  use_worktree=true
else
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
  use_worktree=false
fi

if [ -z "$pr_number" ]; then 
  echo "ERROR: No PR found. Provide URL or ensure current branch has a PR."
  exit 1
fi

# Setup worktree if needed
if [ "$use_worktree" = true ]; then
  # Get PR metadata including base branch
  pr_info=$(gh pr view $pr_number --json headRefName,baseRefName)
  pr_branch=$(echo "$pr_info" | jq -r .headRefName)
  base_branch=$(echo "$pr_info" | jq -r .baseRefName)
  
  # Get git repository root and create worktree directory
  repo_root=$(git rev-parse --show-toplevel)
  worktree_dir="${repo_root}/.worktree/pr-review-${pr_number}"
  
  mkdir -p "${repo_root}/.worktree"
  
  # Fetch latest from remote to avoid stale state
  git fetch origin "$pr_branch"
  
  # Create worktree from remote branch reference
  git worktree add "$worktree_dir" "origin/$pr_branch"
  
  cd "$worktree_dir"
  
  # Verify we're on the latest commit
  latest_commit=$(git log -1 --oneline)
  echo "=== Created worktree at $worktree_dir ==="
  echo "=== Current commit: $latest_commit ==="
  echo "=== Base branch: $base_branch ==="
  
  # Sanity check: verify no newer commits on remote
  git fetch origin "$pr_branch" 2>/dev/null
  newer_commits=$(git log HEAD..origin/$pr_branch --oneline)
  if [ -n "$newer_commits" ]; then
    echo "⚠️  WARNING: Remote has newer commits than worktree!"
    git reset --hard "origin/$pr_branch"
  fi
fi
```

### Phase 2: Fetch PR Information

Single bash command to fetch all required data:

```bash
# Get repository info for API calls
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Fetch all PR information in one command
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== BASE_BRANCH ===" && echo "$base_branch" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== REVIEW_THREADS ===" && gh api "repos/${repo_info}/pulls/${pr_number}/comments" --jq '[.[] | select(.body | contains("🤖 Generated by OpenCode") or .body | contains("🤖 Re-verified by OpenCode")) | {id, path, line, created_at, body, in_reply_to_id}]' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- Worktree created from `origin/$branch` ensures latest state
- Single chained command for efficiency
- Captures PR description and base branch for context
- Fetches all review threads for re-review detection
- Uses correct repo info format for API calls

### Phase 3: Analyze PR Context

**Check for re-review mode**:
- Count previous OpenCode review threads
- If 0: First review - proceed normally
- If 1+: Re-review mode - autonomous execution

**For first reviews**, extract PR context from description:
1. **Purpose**: What is the author trying to achieve?
2. **Scope**: Bug fix, feature, refactor, hotfix?
3. **Constraints**: Any trade-offs or technical debt mentioned?
4. **Testing**: What testing approach was taken?

### Phase 4: Analyze Code

Analyze code directly. Use Task tool only when searching patterns across many files.

**Priority categories**:

**1. Security & Bugs** 🚨 (Always comment if found)
- Security vulnerabilities (SQL injection, XSS, auth bypasses)
- Logic errors, null/undefined handling issues
- Race conditions, deadlocks, resource leaks
- Breaking changes to public APIs

**2. Performance** ⚠️ (Significant impact only)
- N+1 query problems
- Inefficient algorithms (O(n²) when O(n) exists)
- Memory leaks, unnecessary allocations

**3. Architecture & Design** ⚠️ (Established pattern violations)
- Violations of project patterns
- Separation of concerns issues
- Inconsistent error handling

**4. Testing** 💡 (New functionality without tests)
- Missing tests for new features
- Insufficient edge case coverage

**5. Readability** 💡 (Truly confusing code only)
- Confusing variable names or logic
- Missing documentation for public APIs

**For re-reviews**, first verify previous comments:

1. **For each previous comment**:
   - Read file at specified line and surrounding context (±20 lines)
   - Compare current code against described issue
   - Determine status: ✅ Resolved | ⚠️ Partial | ❌ Not Addressed | 🆕 New Issue

2. **Build verification summary** for each:
   ```
   Previous: "🚨 SQL injection vulnerability in login query"
   File: auth.ts:42
   Original issue: String concatenation for SQL query
   Current code: Parameterized query with placeholders
   Verification: ✅ RESOLVED - Properly implemented parameterized queries
   ```

3. **Calculate readiness**:
   - All critical issues resolved?
   - All important issues resolved?
   - No new issues found?
   - If YES to all → Ready for approval

### Phase 5: Apply Comment Filters

**Comment limits**:
- First review: Max 7-10 meaningful comments
- Re-review: Max 3 comments, only for NEW critical issues OR verification

**Re-review filter** - For each potential issue, ask:

1. **Was this file/line previously commented on?**
   - NO → Proceed with normal comment guidelines
   - YES → Check if current "issue" is actually the FIX

2. **Is the current code better than before?**
   - YES → DO NOT comment - mark as RESOLVED
   - NO → Code got worse - comment

**Example**:
```
Previous: "🚨 Deadlock from RLock→Lock→RLock upgrade"
Current:  Uses Lock() everywhere (slower but no deadlock)
Decision: DO NOT comment on performance - RESOLVE instead
```

**Scope filters**:
- Is this code in the diff?
- Within PR's stated purpose?
- Already addressed in PR description?
- Pre-existing issue unrelated to changes?
- **[Re-review]** Is this a fix for previous comment? Better than before?

**Comment guidelines**:
- **Security & Bugs** 🚨: 
  - First review: Always comment on new bugs
  - Re-review: Only if fix introduced new bug OR didn't fix original
- **Performance** ⚠️: 
  - First review: Only significant impact (>20%, quantify)
  - Re-review: NEVER if it fixes correctness/security bug
- **Architecture** ⚠️: Only if violates established patterns
- **Testing** 💡: If new functionality lacks tests
- **Readability** 💡: Only truly confusing code
- **Future Improvements**: Save for summary section

### Phase 7: Post Review

**CRITICAL RULES**:
- ✅ Post ALL comments + summary in ONE review via GitHub API
- ✅ Every review MUST include at least one inline comment OR be an approval
- ✅ For re-reviews: Resolve addressed comments and post verification
- ❌ NEVER post summary-only reviews (cannot be deleted via API)
- ❌ NEVER use `gh pr review --comment` separately

**For first reviews**:

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Create review JSON with ALL comments + summary
cat > /tmp/review_body.txt <<'EOF'
## Overall Review

**Assessment**: [2-3 sentences]

**Strengths**:
- [Specific praise]

**Review breakdown**:
- 🚨 [X] Critical issues
- ⚠️ [X] Important improvements
- 💡 [X] Suggestions

**Future Considerations** (non-blockers):
- [Out-of-scope suggestions]

---
*🤖 Generated by OpenCode*
EOF

cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 42,
      "body": "🚨 **Critical - Security**\n\n**Issue**: SQL injection vulnerability\n\n**Fix**:\n```suggestion\nconst query = 'SELECT * FROM users WHERE id = ?';\nconst result = await db.query(query, [userId]);\n```\n\n**Learning**: Always use parameterized queries to prevent SQL injection\n\n---\n*🤖 Generated by OpenCode*"
    }
  ]
}
EOF

# Post review using gh api
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
  --method POST \
  --input /tmp/review.json \
  -F body=@/tmp/review_body.txt

rm /tmp/review.json /tmp/review_body.txt
```

### Phase 7: Post Review

**CRITICAL RULES**:
- ✅ Post ALL comments + summary in ONE review via GitHub API
- ✅ Every review MUST include at least one inline comment OR be a standalone comment
- ✅ For re-reviews: Resolve addressed comments and post verification
- ✅ NEVER directly approve - always leave approval to human reviewer
- ❌ NEVER post summary-only reviews (cannot be deleted via API)
- ❌ NEVER use `gh pr review --comment` separately

**For first reviews**:

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Create review JSON with ALL comments + summary
cat > /tmp/review_body.txt <<'EOF'
## Overall Review

**Assessment**: [2-3 sentences]

**Strengths**:
- [Specific praise]

**Review breakdown**:
- 🚨 [X] Critical issues
- ⚠️ [X] Important improvements
- 💡 [X] Suggestions

**Future Considerations** (non-blockers):
- [Out-of-scope suggestions]

---
*🤖 Generated by OpenCode*
EOF

cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 42,
      "body": "🚨 **Critical - Security**\n\n**Issue**: SQL injection vulnerability\n\n**Fix**:\n```suggestion\nconst query = 'SELECT * FROM users WHERE id = ?';\nconst result = await db.query(query, [userId]);\n```\n\n**Learning**: Always use parameterized queries to prevent SQL injection\n\n---\n*🤖 Generated by OpenCode*"
    }
  ]
}
EOF

# Post review using gh api
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
  --method POST \
  --input /tmp/review.json \
  -F body=@/tmp/review_body.txt

rm /tmp/review.json /tmp/review_body.txt
```

**For re-reviews (autonomous verification)**:

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Fetch all review threads
review_threads=$(gh api "repos/${repo_info}/pulls/${pr_number}/comments" \
  --jq '[.[] | select(.body | contains("🤖 Generated by OpenCode") or .body | contains("🤖 Re-verified by OpenCode"))]')

# For EACH unresolved thread - verify autonomously
echo "$review_threads" | jq -c '.[]' | while read -r thread; do
  thread_id=$(echo "$thread" | jq -r '.id')
  file_path=$(echo "$thread" | jq -r '.path')
  line_num=$(echo "$thread" | jq -r '.line')
  
  # Read current code at commented location and verify
  # If FIXED: Reply in-thread + mark resolved
  gh api "repos/${repo_info}/pulls/${pr_number}/comments" \
    --method POST \
    --field body="✅ **Verified - Addressed**

The issue has been fixed. The code now:
[specific verification of what changed]

Marking as resolved.

---
*🤖 Re-verified by OpenCode*" \
    --field in_reply_to=$thread_id
  
  # Mark thread as resolved using GraphQL
  gh api graphql -f query="
    mutation {
      resolveReviewThread(input: {threadId: \"$thread_id\"}) {
        thread { isResolved }
      }
    }"
  
  # If NOT FIXED: Reply explaining what's still wrong, leave unresolved
done

# Review new/changed code for additional issues
# If NEW issues → post in-thread comments

# Determine verification status
all_satisfied=true  # Based on verification results
has_new_comments=false  # Based on new issues found

# Post verification summary if all concerns addressed
if [ "$all_satisfied" = true ] && [ "$has_new_comments" = false ]; then
  # ✅ All previous issues resolved AND no new issues → Post verification comment
  gh pr comment $pr_number --body "## ✅ Re-Review Complete - All Concerns Addressed

**All Issues Resolved**:
- ✅ All [X] previous threads verified and resolved
- ✅ No new issues found in recent changes

**Verification Summary**:
| Original Issue | File:Line | Status | Verification |
|---------------|-----------|--------|--------------|
| [issue 1] | file.ts:42 | ✅ Resolved | [how it was fixed] |
| [issue 2] | file.go:57 | ✅ Resolved | [how it was fixed] |

All feedback has been satisfactorily implemented. **Ready for human approval**.

---
*🤖 Re-reviewed by OpenCode*"
  
  echo "✅ All issues resolved - verification summary posted"
else
  # ❌ Some issues remain OR new issues found
  echo "⚠️  Outstanding issues remain or new issues found"
  echo "   - Author must address remaining issues"
  echo "   - Unresolved threads left open for author to review"
fi
```

**Key implementation notes**:
- Suggestion blocks: Use `\`\`\`suggestion` (no language specifier for "Apply" button)
- Every comment MUST end with: `---\n*🤖 Generated by OpenCode*`
- Use `-F field=@file` or `-f field=value` instead of embedding in JSON
- Re-reviews: Use in-thread replies with `--field in_reply_to=$thread_id`
- Thread resolution: Use GraphQL `resolveReviewThread` mutation
- Verification: Use `gh pr comment` to post standalone summary (NEVER approve directly)

**GraphQL thread resolution reference**:

```bash
# Get all review threads with their IDs
thread_data=$(gh api graphql -f query='
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
                body
              }
            }
          }
        }
      }
    }
  }' -f owner="$owner" -f repo="$repo" -F pr=$pr_number)

# Resolve each satisfied thread
for comment_id in "${satisfied_comment_ids[@]}"; do
  thread_id=$(echo "$thread_data" | jq -r \
    ".data.repository.pullRequest.reviewThreads.nodes[] | 
     select(.comments.nodes[].databaseId == $comment_id) | .id")
  
  if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
    gh api graphql -f query='
      mutation($threadId: ID!) {
        resolveReviewThread(input: {threadId: $threadId}) {
          thread { isResolved }
        }
      }' -f threadId="$thread_id"
    
    echo "✅ Resolved thread for comment $comment_id"
  fi
done
```

### Phase 8: Cleanup Worktree

If a worktree was created, clean it up after posting review.

```bash
if [ "$use_worktree" = true ]; then
  cd - > /dev/null
  git worktree remove "$worktree_dir" --force
  echo "=== Cleaned up worktree ==="
fi
```

**Key points**:
- Always clean up worktrees to avoid orphaned directories
- Use `--force` to handle uncommitted changes
- Return to original directory before removal

### Phase 9: Confirm Success

**First review**:
```
✅ Review posted successfully!

Posted [X] inline comments to PR #[NUMBER]:
- 🚨 [X] Critical | ⚠️ [X] Important | 💡 [X] Suggestions

View: [PR_URL]
```

**Re-review (unresolved items remain)**:
```
✅ Re-review posted successfully!

Verification results for PR #[NUMBER]:
- ✅ Resolved: [X] comments (marked as resolved)
- ⚠️ Still open: [Y] comments (need more work)
- 🆕 New issues: [Z] comments

Outstanding work before merge:
- [List of items that still need attention]

View: [PR_URL]
```

**Re-review (all concerns addressed)**:
```
✅ Re-Review Complete - All Concerns Addressed

Verification results for PR #[NUMBER]:
- ✅ All [X] previous threads verified and resolved
- ✅ No new issues found in recent changes
- ✅ Code quality improved

Posted verification summary comment indicating PR is ready for human approval.

View: [PR_URL]
```

## Comment Templates

Every comment MUST end with `---\n*🤖 Generated by OpenCode*`
3. **Approval criteria**: ONLY approve when `all_satisfied=true AND has_new_comments=false`
4. **New issues**: Post as in-thread comments, NOT standalone - never approve until addressed
5. **Autonomous execution**: No user approval needed for individual verification actions

**Key notes**:
- Suggestion blocks: Use `\`\`\`suggestion` (no language specifier for "Apply" button)
- Large reviews (>10 comments): Split into batches, full summary in LAST batch only
- Every comment MUST end with: `---\n*🤖 Generated by OpenCode*`
- Use `-F field=@file` or `-f field=value` instead of embedding in JSON to avoid escaping issues
- **Re-reviews**: Use in-thread replies with `--field in_reply_to=$thread_id`
- **Thread resolution**: Use GraphQL `resolveReviewThread` mutation for programmatic resolution
- **Approval**: Use `gh pr review --approve` ONLY when all issues resolved + no new issues
- Test API endpoints work before relying on them in automation

**Comment Resolution Technical Details**:

GitHub provides limited REST API support for resolving review threads. The most reliable approach is to use GraphQL mutations.

**Recommended: GraphQL API for resolving threads**:
```bash
# Step 1: Get the thread ID for each comment you want to resolve
# You'll need the comment database ID (from the earlier API fetch)

# Get all review threads and find matching comment IDs
thread_data=$(gh api graphql -f query='
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
                body
              }
            }
          }
        }
      }
    }
  }' -f owner="$owner" -f repo="$repo" -F pr=$pr_number)

# Step 2: For each satisfied comment, extract thread ID and resolve it
for comment_id in "${satisfied_comment_ids[@]}"; do
  # Find the thread ID for this comment
  thread_id=$(echo "$thread_data" | jq -r \
    ".data.repository.pullRequest.reviewThreads.nodes[] | 
     select(.comments.nodes[].databaseId == $comment_id) | .id")
  
  if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
    # Resolve the thread
    gh api graphql -f query='
      mutation($threadId: ID!) {
        resolveReviewThread(input: {threadId: $threadId}) {
          thread {
            isResolved
          }
        }
      }' -f threadId="$thread_id"
    
    echo "✅ Resolved thread for comment $comment_id"
  else
    echo "⚠️  Could not find thread for comment $comment_id"
  fi
done
```

**Alternative: Post verification summary** (if GraphQL is too complex):
```bash
# Post a single verification summary comment to the PR
gh pr comment $pr_number --body "## ✅ Review Comments Verified and Resolved

The following previously raised issues have been satisfactorily addressed:

| Original Comment | File:Line | Status | Verification |
|------------------|-----------|--------|--------------|
| SQL injection vulnerability | auth.ts:42 | ✅ Resolved | Now uses parameterized queries correctly |
| Variable naming clarity | utils.ts:55 | ✅ Resolved | Renamed to \`userProfiles\` |
| Potential panic from bounds | selector.go:57 | ✅ Resolved | Added validation before access |

I have manually resolved these comment threads since the issues are now fixed.

---
*🤖 Re-verified by OpenCode*"

# Then manually resolve each thread (or let the reviewer do it)
```

**Important**:
- GitHub's REST API doesn't provide a direct way to resolve review threads
- GraphQL `resolveReviewThread` mutation is the programmatic solution
- Threads can only be resolved by the reviewer who created them or repo maintainers
- **Best Practice**: Use GraphQL to resolve threads automatically when all concerns addressed
- Fallback: Post verification summary and let reviewers manually resolve
- Resolved threads signal to the PR author that issues are addressed

**Re-Review Strategy**:
1. **Verify each previous comment** against current code
2. **Post verification replies** on satisfied comments and resolve threads
3. **Track resolution status** in summary table
4. **Post approval comment** if all satisfied and no new critical issues
5. **Post re-review summary** if work remains
6. **Clear signal** to author about merge readiness

### Phase 8: Cleanup Worktree

**CRITICAL**: If a worktree was created, clean it up after posting review.

```bash
if [ "$use_worktree" = true ]; then
  # Return to original directory
  cd - > /dev/null
  
  # Remove worktree
  git worktree remove "$worktree_dir" --force
  
  echo "=== Cleaned up worktree ==="
fi
```

**Key points**:
- Always clean up worktrees to avoid leaving orphaned directories
- Use `--force` to handle any uncommitted changes in worktree
- Return to original directory before removal

### Phase 9: Confirm Success

Display confirmation message based on review type:

**First Review**:
```
✅ Review posted successfully!

Posted [X] inline comments to PR #[NUMBER]:
- 🚨 [X] Critical | ⚠️ [X] Important | 💡 [X] Suggestions

View: [PR_URL]
```

**Re-Review (with unresolved items)**:
```
✅ Re-review posted successfully!

Verification results for PR #[NUMBER]:
- ✅ Resolved: [X] comments (marked as resolved)
- ⚠️ Still open: [Y] comments (need more work)
- 🆕 New issues: [Z] comments

Outstanding work before merge:
- [List of items that still need attention]

View: [PR_URL]
```

**Re-Review (all satisfied - GitHub Approved)**:
```
✅ Re-Review Complete - APPROVED 🎉

Re-review results for PR #[NUMBER]:
- ✅ All [X] previous threads verified and resolved
- ✅ No new issues found in recent changes
- ✅ Code quality improved

All review feedback has been satisfactorily implemented.
GitHub PR has been APPROVED - ready to merge.

View: [PR_URL]
```

## Comment Templates

Every comment MUST end with `---\n*🤖 Generated by OpenCode*`

### Security Issue (Critical)

```markdown
🚨 **Critical - Security**

**Issue**: [e.g., SQL injection vulnerability]

**Why critical**: [Security risk and attack vector]

**Fix**:
\`\`\`suggestion
// Secure implementation
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
\`\`\`

**Learning**: [Security principle or best practice]

**References**: [OWASP link or codebase example if relevant]

---
*🤖 Generated by OpenCode*
```

### Performance Issue (Important)

```markdown
⚠️ **Important - Performance**

**Issue**: [e.g., N+1 query - creates 101 DB calls for 100 posts]

**Why this matters**: [Performance impact with numbers]

**Fix**:
\`\`\`suggestion
// Batch fetch in one query
const postIds = posts.map(p => p.id);
const allComments = await db.query(
  'SELECT * FROM comments WHERE post_id IN (?)',
  [postIds]
);
\`\`\`

**Impact**: [Quantified - "101 queries → 2 queries (50x faster)"]

**Learning**: [Performance principle]

---
*🤖 Generated by OpenCode*
```

### Architecture/Design (Important)

```markdown
⚠️ **Important - Architecture**

**Issue**: [e.g., Business logic in controller layer]

**Why this matters**: [Maintainability/testability impact]

**Fix**:
\`\`\`suggestion
// Extract to service layer
export class UserController {
  constructor(private userService: UserService) {}
  
  async createUser(req, res) {
    const user = await this.userService.createUser(req.body);
    res.json(user);
  }
}
\`\`\`

**Benefits**: [Testability, reusability, clarity]

**Learning**: [Design principle]

---
*🤖 Generated by OpenCode*
```

### Readability (Suggestion)

```markdown
💡 **Suggestion - Readability**

**Why**: [e.g., "Descriptive names make code self-documenting"]

**Suggestion**:
\`\`\`suggestion
const activeUserProfiles = data
  .filter(item => item.status === 1)
  .map(item => item.value);
\`\`\`

**Principle**: Code is read 10x more than written - optimize for clarity

---
*🤖 Generated by OpenCode*
```

### Question/Discussion

```markdown
❓ **Question - Design Decision**

I noticed [observation]. Was this because [potential reason]?

\`\`\`typescript
[code in question]
\`\`\`

**Trade-offs**:
- Current approach: [pros/cons]
- Alternative: [pros/cons]

Would love to understand your reasoning!

---
*🤖 Generated by OpenCode*
```

### Praise

```markdown
✅ **Great Implementation**

[Specific praise about what's done well]

\`\`\`typescript
[the good code]
\`\`\`

[Why this is good - principle followed, problem solved elegantly]

---
*🤖 Generated by OpenCode*
```

## Best Practices

### Writing Educational Comments

**1. Explain "Why"** - Don't just say what to change
- ❌ Bad: "This variable name is wrong"
- ✅ Good: "Rename `data` to `userProfiles` - specific names make code self-documenting"

**2. Provide Context** - Reference standards/patterns
- "Violates SRP - function both fetches AND formats data"
- "Project follows Repository pattern (see user-repository.ts:10)"

**3. Offer Solutions** - Include code examples
- Show the better approach
- Explain trade-offs
- Make it copy-pasteable

**4. Be Specific** - Comment on exact lines
- Quote problematic code
- Show exact improved version

**5. Balance with Praise**
- Leave positive comments on well-written code
- Use emojis: ✅ for praise, 🚨 ⚠️ 💡 for issues

**6. Ask Questions** - Frame as curiosity
- "Why X instead of Y - to avoid Z?"
- Assume good reasons exist

### Tone Guidelines

- **Collaborative**: "We could..." not "You did this wrong"
- **Curious**: "Why this approach?" not "This is wrong"
- **Teaching**: "Here's why..." not "Just use this"
- **Respectful**: Assume good intentions
- **Empathetic**: Everyone is learning

## Error Handling

Common error scenarios and responses:

**General errors**:
- **No PR found**: Ask user for PR URL
- **Invalid URL format**: Show expected format example
- **PR closed/merged**: Ask if they want to review anyway
- **Insufficient permissions**: Suggest `gh auth login`
- **Empty diff**: Inform no changes to review
- **API rate limit**: Wait and retry with exponential backoff

**Worktree errors**:
- **Creation fails**: Check if branch exists, fetch if needed, ensure `.worktree` is writable
- **Cleanup fails**: Force remove and warn about manual cleanup if needed
- **Stale state**: Always create from `origin/$branch`, verify commit matches remote
- **Diff vs file mismatch**: Indicates stale worktree, run `git reset --hard origin/$pr_branch`

**Re-review specific**:
- **File moved/deleted**: Note in verification that file no longer exists
- **Line numbers shifted**: Use fuzzy matching or note code was restructured
- **All comments resolved**: Skip re-review, just check for new issues
- **No changes since last**: Warn user code hasn't changed

**Worktree state troubleshooting checklist**:
1. ✅ Verify on latest commit: `git log -1 --oneline`
2. ✅ Check for newer commits: `git log HEAD..origin/$pr_branch --oneline`
3. ✅ Verify file line counts: `wc -l suspicious_file.go`
4. ✅ Confirm base branch: `echo $base_branch`
5. ✅ If any fail: `git fetch origin $pr_branch && git reset --hard origin/$pr_branch`

**Critical reminders**:
- NEVER assume base branch is `main` or `master`
- ALWAYS query: `gh pr view $pr_number --json baseRefName -q .baseRefName`
- If `gh pr diff` line counts don't match files: worktree is stale

## Edge Cases

- **Large PRs (100+ files)**: Focus on critical changes, note scope limitation
- **Auto-generated code**: Skip package-lock.json, generated protobuf, etc.
- **Formatting-only changes**: Post positive comment noting no issues
- **WIP/Draft PRs**: Lighter review focusing on approach validation
- **Dependency updates**: Focus on changelog, security advisories, breaking changes

## Success Criteria

A successful review meets these requirements:

### First Review
- ✅ Presents review to user for approval BEFORE posting
- ✅ Includes OpenCode watermark on every comment and summary
- ✅ Posts as inline comments on specific lines with context
- ✅ Provides educational explanations with "why" not just "what"
- ✅ Offers concrete, actionable code examples
- ✅ Balances constructive criticism with genuine praise
- ✅ Gives clear, implementable next steps
- ✅ Feels like learning from an experienced developer

### Re-Review
- ✅ Fetches all review threads autonomously
- ✅ For each unresolved thread: Verifies, replies in-thread, marks resolved if fixed
- ✅ Reviews new/changed code and posts in-thread comments for new issues
- ✅ Uses GraphQL to mark threads as resolved programmatically
- ✅ Posts verification summary when all concerns addressed (ready for human approval)
- ✅ Executes autonomously - no user approval needed for individual verification actions
- ✅ NEVER directly approves - always leaves approval to human reviewer

### Merge Readiness (for re-reviews)
- ✅ ALL critical (🚨) issues verified fixed and threads resolved
- ✅ ALL important (⚠️) issues verified fixed and threads resolved
- ✅ NO new issues found in recent changes
- ✅ Code quality improved from previous review
- ➡️ Result: Post verification summary comment indicating ready for human approval
- ❌ If ANY issues remain (old or new): DO NOT post summary, leave threads unresolved

---

**Remember**: Every review is a teaching opportunity. Help developers grow their skills, not just improve one PR.

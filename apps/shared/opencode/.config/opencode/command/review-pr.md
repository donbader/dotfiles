---
name: git:review-pr
description: Provide comprehensive, educational code review for GitHub PRs
---

# Review GitHub Pull Request

Perform thorough, educational code reviews that help developers learn and improve code quality through constructive feedback.

## Usage

**Command syntax**:
```bash
/git:review-pr [PR_URL]
```

**Examples**:
```bash
# Review specific PR by URL
/git:review-pr https://github.com/owner/repo/pull/123

# Review PR for current branch (auto-detect)
/git:review-pr

# Re-run review on same PR to verify fixes
/git:review-pr https://github.com/owner/repo/pull/123
# Automatically detects previous OpenCode reviews and:
# - Verifies which comments were addressed
# - Resolves satisfied comments
# - Posts approval comment if all concerns addressed
# - Posts new comments only for new issues
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

**Re-Review Behavior**:
When previous OpenCode review comments exist on the PR, the tool automatically switches to "re-review mode":
- Verifies each previous comment against current code
- Resolves comments that were satisfactorily addressed
- Only posts new comments for new issues or unaddressed items
- Posts approval comment (not GitHub PR approval) if all concerns resolved
- Provides clear merge readiness signal to author

## Complete Workflow Example

**Reviewing PR from URL** (uses worktree):
1. User provides PR URL → Create worktree for that PR's branch
2. Fetch PR information in worktree context
3. Analyze code and generate review comments
4. Present to user for approval
5. Post review to GitHub
6. Clean up worktree → User's original work unchanged

**Reviewing current branch** (no worktree):
1. Auto-detect PR from current branch
2. Fetch PR information
3. Analyze code and generate review comments
4. Present to user for approval  
5. Post review to GitHub

**Re-reviewing PR** (verification mode):
1. User runs `/git:review-pr` on previously reviewed PR
2. Tool detects previous OpenCode comments
3. For each previous comment:
   - Read current code at commented location
   - Verify if issue was addressed
   - Classify: ✅ Resolved | ⚠️ Partial | ❌ Not addressed
4. Present verification summary to user
5. Post verification replies on satisfied comments and resolve threads
6. If ALL concerns addressed + no new critical issues:
   - Post approval comment with verification summary
   - Signal "Ready to merge"
7. If work remains:
   - Post re-review summary with status table
   - List outstanding items
   - Post new comments only for new issues
8. Clean up worktree if used

## Review Philosophy

Effective code reviews should be:
- **Educational**: Explain WHY changes are needed, not just WHAT
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact files, line numbers, and code patterns
- **Balanced**: Acknowledge strengths AND identify improvements
- **Actionable**: Provide clear, implementable next steps
- **Focused**: Comment only on code within PR scope
- **Context-aware**: Understand PR intent from description

**Goal**: Every review should be a learning opportunity that improves developer skills.

## Core Principles

### 1. Stay Within Scope

**Inline Comments** - Only for code changes in this PR:
- Security vulnerabilities, bugs, breaking changes
- Performance problems in modified code
- Architecture violations in changed code
- Missing tests for new functionality
- Readability issues in changed code

**Summary Section** - For broader suggestions:
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

**Context-aware review examples**:
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
echo "=== PREVIOUS_OPENCODE_REVIEWS ===" && gh api "repos/${repo_info}/pulls/${pr_number}/comments" --jq '[.[] | select(.body | contains("🤖 Generated by OpenCode")) | {id, path, line, created_at, body, in_reply_to_id}]' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- Worktree created from `origin/$branch` (not local branch) to ensure latest state
- Single chained command for efficiency
- Captures PR description AND base branch for context
- **Fetches previous OpenCode review comments** with full details for re-review
- Uses correct repo info format for API calls

### Phase 3: Analyze PR Context and Review History

**STEP 1: Check if this is a re-review**

Count previous OpenCode reviews from the fetched data:
- If 0 previous reviews: This is first review, proceed normally
- If 1+ previous reviews: **RE-REVIEW MODE** - be much more conservative

**STEP 2: If re-review, identify which files/lines were previously commented on**

Create a mental map:
```
Previously commented files:
- sliding_window.go:46 - "Deadlock from lock upgrade"
- provider_state.go:50 - "Race condition in check-then-act"
- selector.go:57 - "Potential panic from RandomInt"
```

**STEP 3: Extract PR context** from description:
1. **Purpose**: What is the author trying to achieve?
2. **Scope**: Bug fix, feature, refactor, hotfix?
3. **Constraints**: Any trade-offs or technical debt mentioned?
4. **Testing**: What testing approach was taken?

### Phase 4: Analyze Code

**IMPORTANT**: Analyze code directly. Do NOT use Task tool unless searching patterns across many files.

**For RE-REVIEWS**: First verify previous comments before analyzing for new issues.

**Re-Review Verification Steps** (if previous OpenCode comments exist):

1. **For each previous comment**:
   - Read the file mentioned in the comment at the specified line
   - Read surrounding context (±20 lines) to understand the change
   - Compare current code against the issue described in the comment
   - Determine status:
     - ✅ **Resolved**: Issue no longer exists, code properly fixed
     - ⚠️ **Partial**: Some improvement but incomplete fix
     - ❌ **Not Addressed**: Issue still exists as originally described
     - 🆕 **New Issue**: Fix introduced a new problem

2. **Build verification summary**:
   ```
   Previous comment: "🚨 SQL injection vulnerability in login query"
   File: auth.ts:42
   
   Original issue: Used string concatenation for SQL query
   Current code: Uses parameterized query with placeholders
   
   Verification: ✅ RESOLVED - Properly implemented parameterized queries
   ```

3. **Calculate satisfaction score**:
   - Critical comments resolved: [X]/[Y]
   - Important comments resolved: [X]/[Y]
   - All critical resolved AND (all important resolved OR acknowledged with plan) → READY FOR APPROVAL

**Analysis steps** (for NEW issues or first review):
1. Read the PR diff to identify changed files and line ranges
2. Read 3-5 most important changed files for full context
3. Analyze changes for issues (see priority categories below)

**Priority categories for review**:

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

**When to use Task tool** (rarely):
Only when you need to search patterns across many files to validate a concern.

Example: "Search error handling patterns in src/controllers/*.ts to verify consistency"

### Phase 5: Identify Issues and Check Previous Comments

**Comment limits**:
- **First review**: Max 7-10 meaningful comments
- **Re-review (2nd+ time)**: Max 3 comments, ONLY for NEW critical issues OR focus on verification

**CRITICAL: Re-review filter (if previous OpenCode comments exist)**

When re-running a review, your primary goal is to **verify if previous comments were addressed** and **resolve those that were fixed**.

For each potential issue you want to comment on, ask:

1. **Was this file/line previously commented on?**
   - If NO → Proceed with normal comment guidelines below
   - If YES → Go to step 2

2. **What was the previous comment about?**
   - Read the previous comment issue
   - Example: "🚨 Deadlock from lock upgrade pattern"

3. **How did the code change?**
   - Compare current code with what would have existed before
   - Example: Changed from `RLock()→Unlock()→Lock()` to `Lock()` everywhere

4. **Is the current "issue" actually the FIX for the previous issue?**
   - Example: Using `Lock()` everywhere is SLOWER, but it FIXED the deadlock
   - If YES → **DO NOT COMMENT** - Mark as RESOLVED instead
   - If NO → The previous issue is unfixed or a new bug appeared → Comment

5. **Apply the "Better than Before" rule:**
   - Is current code BETTER than before the fix? (even if imperfect)
     - If YES → **DO NOT COMMENT** - Mark as RESOLVED instead
     - If NO → Code got worse → Comment

**Example of what NOT to comment on (re-review)**:
```
Previous: "🚨 Deadlock from RLock→Lock→RLock upgrade pattern"
Current:  Uses Lock() everywhere (slower but no deadlock)
Decision: DO NOT comment on performance - RESOLVE the previous comment instead
```

**Scope filters** (ask yourself):
- Is this code in the diff?
- Within PR's stated purpose?
- Already addressed in PR description?
- Pre-existing issue unrelated to these changes?
- **[RE-REVIEW ONLY]** Is this code a fix for a previous comment?
  - If yes: Is it better than before, even if imperfect? → Skip

**Comment guidelines by category**:
- **Security & Bugs** 🚨: 
  - First review: Always comment on new bugs
  - Re-review: Only if fix INTRODUCED a new bug OR didn't fix original bug
- **Performance** ⚠️: 
  - First review: Only significant impact (>20% degradation, quantify)
  - Re-review: **NEVER comment if it fixes a correctness/security bug**
- **Architecture** ⚠️: Only if violates established patterns
- **Testing** 💡: If new functionality lacks tests
- **Readability** 💡: Only truly confusing code
- **Future Improvements**: Save for summary section

### Phase 6: Present for User Approval

**CRITICAL**: Present review to user for approval BEFORE posting.

**For re-reviews with previous OpenCode comments**: Also present verification results.

**Display format (first review)**:
```
## Review Summary for PR #[NUMBER]: [Title]

**Found [X] comments**:
- 🚨 [X] Critical (security, bugs)
- ⚠️ [X] Important (performance, architecture)
- 💡 [X] Suggestions (readability, best practices)

**Comments to post**:

1. 🚨 auth.ts:42 - SQL injection vulnerability in login query
2. ⚠️ user-controller.ts:85 - N+1 query problem fetching user posts
3. 💡 user-service.ts:55 - Variable `d` should be `userProfiles`

**Post these comments to the PR?** (y/n)
```

**Display format (re-review)**:
```
## Re-Review Summary for PR #[NUMBER]: [Title]

**Previous OpenCode Review**: Found [X] previous comments from [date]

**Verification Results**:
- ✅ [X] Addressed satisfactorily (will resolve)
- ⚠️ [X] Partially addressed (needs follow-up)
- ❌ [X] Not addressed yet (remains open)
- 🆕 [X] New issues found

**Comments to resolve** (author addressed these):
1. ✅ auth.ts:42 - SQL injection vulnerability → Fixed with parameterized queries
2. ✅ utils.ts:55 - Variable naming → Renamed to `userProfiles`

**Comments to keep open** (still need work):
3. ⚠️ selector.ts:50 - Potential panic → Partially addressed, still needs bounds check

**New comments to post**:
4. 🚨 handler.ts:78 - New critical issue: Race condition introduced

**Overall Assessment**:
- Author addressed [X] out of [Y] previous comments ([Z]%)
- [X] comments can be resolved
- [Y] comments need more work
- Ready for merge: YES/NO

**Proceed with posting this re-review?** (y/n)
- Will resolve [X] satisfied comments
- Will keep [Y] comments open
- Will post [Z] new comments
```

**Wait for user confirmation** before proceeding to Phase 7.

### Phase 7: Post Review and Resolve Comments

**CRITICAL RULES**:
- ✅ Post ALL comments + summary in ONE review via GitHub API
- ✅ Every review MUST include at least one inline comment OR be an approval
- ✅ For re-reviews: Resolve addressed comments and post verification summary
- ❌ NEVER post summary-only reviews (cannot be deleted via API)
- ❌ NEVER use `gh pr review --comment` separately

**For First Review** (JSON to temp file):

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Create review JSON with ALL comments + summary
# NOTE: Use -f for fields to avoid JSON escaping issues with --input
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

# Post review using gh api (more reliable than gh pr review)
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
  --method POST \
  --input /tmp/review.json \
  -F body=@/tmp/review_body.txt

# Clean up
rm /tmp/review.json /tmp/review_body.txt
```

**For Re-Review** (verify and resolve comments):

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Step 1: Resolve SATISFIED previous OpenCode comments
# Get all unresolved previous OpenCode review comments
previous_comments=$(gh api "repos/${repo_info}/pulls/${pr_number}/comments" \
  --jq '[.[] | select(.body | contains("🤖 Generated by OpenCode")) | {id, path, line, body, pull_request_review_id}]')

# For each comment that was addressed satisfactorily, resolve it
# Resolving is done by creating a reply and then resolving the thread
for comment in "${satisfied_comments[@]}"; do
  comment_id="${comment[id]}"
  
  # Post verification reply to the comment
  gh pr comment $pr_number --body "✅ **Verified - Addressed**

The author has satisfactorily addressed this concern. The code now:
${comment[verification]}

Marking as resolved.

---
*🤖 Re-verified by OpenCode*"
  
  # Resolve the comment thread using GraphQL (REST API doesn't support this well)
  # First get the thread ID from the comment
  thread_id=$(gh api "repos/${repo_info}/pulls/comments/${comment_id}" --jq '.pull_request_review_id')
  
  # Note: Resolving threads requires GraphQL mutation
  # For simplicity, use gh pr comment with resolved flag if available
  # Otherwise, threads can be manually resolved by reviewers after reading verification
done

# Step 2: Post re-review summary
all_satisfied=true  # Set based on verification results
has_new_comments=false  # Set based on new issues found

if [ "$all_satisfied" = true ] && [ "$has_new_comments" = false ]; then
  # All previous comments addressed, no new issues - POST APPROVAL COMMENT
  cat > /tmp/review_body.txt <<'EOF'
## ✅ Re-Review Complete - OpenCode Approved

**Previous Review Status**:
- ✅ [X] comments addressed satisfactorily (marked as resolved)
- Total verification: [X]/[Y] items resolved

**Verification Summary**:

| Original Comment | File:Line | Status | Verification |
|------------------|-----------|--------|--------------|
| SQL injection | auth.ts:42 | ✅ Resolved | Now uses parameterized queries correctly |
| Variable naming | utils.ts:55 | ✅ Resolved | Renamed to `userProfiles` |
| Panic handling | selector.go:57 | ✅ Resolved | Added bounds validation |

**Overall Assessment**:
All previous concerns have been addressed. The author has:
- [Specific improvement 1]
- [Specific improvement 2]
- [Specific improvement 3]

✅ **OpenCode Approval: Ready to merge** - All review feedback has been satisfactorily implemented.

Great work addressing all the feedback! 🎉

---
*🤖 Re-reviewed by OpenCode*
EOF

  # Post as a PR comment (not GitHub approval - user decides when to approve)
  gh pr comment $pr_number --body-file /tmp/review_body.txt
  
  echo "✅ OpenCode approval posted - All comments resolved, ready to merge"

else
  # Some comments not addressed or new issues found - post COMMENT review
  cat > /tmp/review_body.txt <<'EOF'
## 🔄 Re-Review Summary

**Previous Review Status**:
- ✅ [X] comments addressed satisfactorily (marked as resolved)
- ⚠️ [Y] comments partially addressed (need follow-up)
- ❌ [Z] comments not yet addressed

**Verification Summary**:

| Original Comment | File:Line | Status | Verification |
|------------------|-----------|--------|--------------|
| SQL injection | auth.ts:42 | ✅ Resolved | Now uses parameterized queries correctly |
| Variable naming | utils.ts:55 | ✅ Resolved | Renamed to `userProfiles` |
| Panic handling | selector.ts:50 | ⚠️ Partial | Added check but still needs bounds validation |

**Outstanding Items**:
- [List items that still need work]

**New Issues** (if any):
- [List new issues found]

**Next Steps**:
- Address remaining [Y] outstanding items
- Once all addressed, will post approval comment

Great progress on the fixes! 👍

---
*🤖 Re-reviewed by OpenCode*
EOF

  # If there are new comments, create review with them
  if [ "$has_new_comments" = true ]; then
    cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "comments": [
    {
      "path": "[file_path]",
      "line": [line_number],
      "body": "[New issue or follow-up comment]"
    }
  ]
}
EOF

    gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
      --method POST \
      --input /tmp/review.json \
      -F body=@/tmp/review_body.txt
  else
    # No new comments, just post verification summary as PR comment
    gh pr comment $pr_number --body-file /tmp/review_body.txt
  fi
fi

# Clean up
rm -f /tmp/review.json /tmp/review_body.txt
```

**Key notes**:
- Suggestion blocks: Use `\`\`\`suggestion` (no language specifier for "Apply" button)
- Large reviews (>10 comments): Split into batches, full summary in LAST batch only
- Every comment MUST end with: `---\n*🤖 Generated by OpenCode*`
- Use `-F field=@file` or `-f field=value` instead of embedding in JSON to avoid escaping issues
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

**Re-Review (all satisfied - OpenCode Approved)**:
```
✅ OpenCode Approval Posted - Ready to merge! 🎉

Re-review results for PR #[NUMBER]:
- ✅ All [X] previous comments addressed
- ✅ No new critical issues found
- ✅ Code quality improved

All review feedback has been satisfactorily implemented.
OpenCode recommends this PR is ready to merge.

View: [PR_URL]
```

## Comment Templates

**Required footer**: Every comment MUST end with `---\n*🤖 Generated by OpenCode*`

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

## Review Best Practices

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

## Critical: Avoid Common Mistakes

### Never Post Summary-Only Reviews

**Problem**: Summary-only reviews (without inline comments) cannot be deleted via GitHub API.

**Wrong approach**:
```bash
# DON'T DO THIS - creates non-deletable review
gh pr review ${pr_number} --comment --body "## Review Summary..."
```

**Correct approach**:
```bash
# Post everything in ONE review with inline comments
{
  "event": "COMMENT",
  "body": "## Overall Review...",
  "comments": [
    {"path": "file.go", "line": 42, "body": "Comment 1..."},
    {"path": "file.go", "line": 108, "body": "Comment 2..."}
  ]
}
```

**Key rule**: Every review MUST include at least one inline comment (except APPROVE reviews).

### Re-Review Comment Resolution

**How to properly resolve previous comments**:

```bash
# 1. Post verification reply as a general PR comment (most reliable)
gh pr comment $pr_number --body "## ✅ Previous Comments Verified

| Comment | Status | Verification |
|---------|--------|--------------|
| auth.ts:42 SQL injection | ✅ Resolved | Uses parameterized queries |
| utils.ts:55 Variable naming | ✅ Resolved | Renamed to userProfiles |

---
*🤖 Re-verified by OpenCode*"

# 2. Then reviewers can manually resolve threads
# OR use GraphQL to resolve programmatically (more complex):
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "THREAD_ID_HERE"}) {
    thread {
      isResolved
    }
  }
}'
```

**Important**:
- GitHub's REST API doesn't have a simple endpoint for resolving threads
- Posting verification summaries is most reliable
- Reviewers can manually resolve after reading verification
- Use approval reviews to signal all concerns addressed

### Re-Review Example: From Issues to Approval

**Initial review (3 comments)**:
```
🚨 auth.ts:42 - SQL injection vulnerability
⚠️ controller.ts:85 - N+1 query problem  
💡 utils.ts:55 - Variable naming
```

**Author makes fixes, you re-run `/git:review-pr`**:

**Tool verifies**:
- ✅ auth.ts:42 - Now uses parameterized queries (RESOLVED)
- ✅ controller.ts:85 - Implemented batch loading (RESOLVED)
- ✅ utils.ts:55 - Renamed to `userProfiles` (RESOLVED)
- No new issues found

**Tool posts**:
```markdown
## ✅ Re-Review Complete - OpenCode Approved

All 3 previous comments addressed satisfactorily:
- ✅ SQL injection fixed with parameterized queries
- ✅ N+1 query resolved with batch loading
- ✅ Variable renamed for clarity

✅ **OpenCode Approval: Ready to merge** - All feedback implemented.

Great work! 🎉
```

**Result**: OpenCode approval comment posted, user can approve and merge confidently.

## Error Handling

Common error scenarios and responses:

- **No PR found**: Ask user for PR URL
- **Invalid URL format**: Show expected format example
- **PR closed/merged**: Ask if they want to review anyway
- **Insufficient permissions**: Suggest `gh auth login`
- **Empty diff**: Inform that there are no changes to review
- **API rate limit**: Wait and retry with exponential backoff
- **Worktree creation fails**: 
  - Check if branch exists and fetch if needed
  - Ensure `.worktree` directory is writable
  - Clean up any existing worktree at that path
- **Worktree cleanup fails**: Force remove and warn user about manual cleanup if needed

**Re-Review Specific**:
- **Previous comment file moved/deleted**: Note in verification that file no longer exists
- **Line numbers shifted**: Use fuzzy matching or note that code was restructured
- **Cannot resolve threads via API**: Use GraphQL mutation (see Phase 7 details)
- **All comments already resolved**: Inform user and skip re-review, just check for new issues
- **No changes since last review**: Warn user that code hasn't changed since last review

**Worktree State Issues** (Critical):
- **Stale worktree state**: 
  - ALWAYS create worktree from `origin/$branch`, not local branch reference
  - Verify worktree commit matches remote immediately after creation
  - If `gh pr diff` shows different line counts than actual files, worktree is stale
  - Fix: `git fetch origin $pr_branch && git reset --hard origin/$pr_branch`
  
- **Base branch assumption**:
  - NEVER assume base branch is `main` or `master`
  - ALWAYS query base branch: `gh pr view $pr_number --json baseRefName -q .baseRefName`
  - Use queried base branch for all diffs and comparisons
  
- **Diff vs file mismatch**:
  - If `gh pr diff` shows 68 lines but file has 57 lines: RED FLAG
  - Sanity check: `wc -l file.go` should match expectations
  - Verify commit: `git log -1 --oneline` should match PR's latest commit
  - Check for newer commits: `git log HEAD..origin/$pr_branch --oneline` (should be empty)
  - If non-empty: Run `git reset --hard origin/$pr_branch` to sync worktree

**Troubleshooting Checklist**:

When something seems off during review:
1. ✅ Verify worktree is on latest commit: `git log -1 --oneline`
2. ✅ Check if remote has newer commits: `git log HEAD..origin/$pr_branch --oneline`
3. ✅ Verify file line counts match diff expectations: `wc -l suspicious_file.go`
4. ✅ Confirm base branch is correct: `echo $base_branch` (from PR metadata)
5. ✅ If any checks fail: `git fetch origin $pr_branch && git reset --hard origin/$pr_branch`

## Edge Cases

Special PR scenarios to handle:

- **Large PRs (100+ files)**: Focus on critical changes, note scope limitation in summary
- **Auto-generated code**: Skip files like package-lock.json, generated protobuf, etc.
- **Formatting-only changes**: Quick approval with note about automation
- **WIP/Draft PRs**: Lighter review focusing on approach validation
- **Dependency updates**: Focus on changelog, security advisories, breaking changes

## Success Criteria

A successful review meets these requirements:

**First Review**:
- ✅ Presents review to user for approval BEFORE posting
- ✅ Includes OpenCode watermark on every comment and summary
- ✅ Posts as inline comments on specific lines with context
- ✅ Provides educational explanations with "why" not just "what"
- ✅ Offers concrete, actionable code examples
- ✅ Balances constructive criticism with genuine praise
- ✅ Gives clear, implementable next steps
- ✅ Feels like learning from an experienced developer

**Re-Review**:
- ✅ Verifies each previous OpenCode comment against current code
- ✅ Posts verification notes on addressed comments and resolves threads
- ✅ Presents clear summary table showing status of all previous comments
- ✅ Only posts NEW comments for NEW issues or unaddressed items
- ✅ Posts approval comment (not GitHub PR approval) if ALL concerns addressed
- ✅ Provides clear signal to author about merge readiness
- ✅ Acknowledges author's progress on fixes
- ✅ Leaves final PR approval decision to the user

**Merge Readiness Criteria** (for re-reviews):
- ✅ ALL critical (🚨) comments addressed
- ✅ ALL important (⚠️) comments addressed OR acknowledged with plan
- ✅ NO new critical issues found
- ✅ Code quality improved from previous review
- ➡️ Result: Post approval COMMENT (not PR approval) + "Ready to merge" message

---

**Remember**: Every review is a teaching opportunity. The goal is to help developers grow their skills, not just improve one PR.

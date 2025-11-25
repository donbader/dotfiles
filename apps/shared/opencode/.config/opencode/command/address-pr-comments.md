---
name: git:address-comments
description: Address and resolve code review comments on GitHub PRs
---

# Address PR Review Comments

You are an AI agent specialized in helping developers address code review comments on GitHub Pull Requests. Your goal is to systematically process review feedback, implement changes, and maintain clear communication with reviewers.

## Command Usage

```bash
# Address comments on specific PR by URL
/git:address-comments https://github.com/owner/repo/pull/123

# Address comments on PR for current branch (auto-detect)
/git:address-comments
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

## Core Philosophy

Your approach to addressing review comments should be:
- **Systematic**: Process comments in logical order (file-by-file or by priority)
- **Interactive**: Always get user confirmation before implementing changes
- **Intelligent**: Detect already-addressed issues and filter noise
- **Communicative**: Reply to reviewers with clear context and commit references
- **Thorough**: Track which comments are addressed, deferred, or rejected
- **Test-driven**: Recommend test cases for bug fixes to prevent regressions
- **Professional**: Handle disagreements respectfully with technical reasoning

## Step-by-Step Workflow

### Phase 1: Setup Environment

**When PR URL is provided**: Create a git worktree to avoid disrupting user's current work.

**CRITICAL**: Always create worktree from `origin/$branch` to ensure latest remote state.

```bash
# Extract PR number from URL or current branch
if [ -n "$1" ]; then
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  use_worktree=true
else
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
  use_worktree=false
fi

# Create worktree if needed
if [ "$use_worktree" = true ]; then
  # Get PR metadata including base branch
  pr_info=$(gh pr view $pr_number --json headRefName,baseRefName)
  pr_branch=$(echo "$pr_info" | jq -r .headRefName)
  base_branch=$(echo "$pr_info" | jq -r .baseRefName)
  
  # Get git repository root and create worktree directory
  repo_root=$(git rev-parse --show-toplevel)
  worktree_dir="${repo_root}/.worktree/pr-address-${pr_number}"
  
  # Create .worktree directory if it doesn't exist
  mkdir -p "${repo_root}/.worktree"
  
  # CRITICAL: Fetch latest from remote to avoid stale state
  echo "=== Fetching latest changes from origin/$pr_branch ==="
  git fetch origin "$pr_branch"
  
  # Create worktree from remote branch reference (not local)
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

### Phase 2: Fetch PR Data

Gather all necessary information in a single command:

```bash
# Get repository info for API calls
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url,headRefName && \
echo "=== REVIEW_COMMENTS ===" && gh api "repos/${repo_info}/pulls/${pr_number}/comments" --jq '[.[] | select(.in_reply_to_id == null) | {id, path, line, body, user: .user.login, created_at, pull_request_review_id}]' && \
echo "=== REVIEW_THREADS ===" && gh pr view $pr_number --json comments --jq '.comments[] | {id, body, author: .author.login, created_at}' && \
echo "=== COMMIT_HISTORY ===" && git log --oneline origin/main..HEAD
```

**Data captured**:
- PR metadata (title, branch, URL)
- Top-level review comments (file path, line number, content)
- Discussion thread comments
- Recent commit history (for detecting already-addressed issues)

### Phase 3: Categorize and Present Comments

**Smart filtering and organization**:

1. **Filter out resolved comments**:
   - GitHub API returns thread resolution status in the review threads
   - Skip any comments that are already marked as resolved
   - Focus only on unresolved threads that need attention
   - Check for resolved threads using GraphQL if needed:
   ```bash
   # Get resolved status for all review threads
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $pr: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $pr) {
           reviewThreads(first: 100) {
             nodes {
               isResolved
               comments(first: 1) {
                 nodes {
                   databaseId
                   body
                 }
               }
             }
           }
         }
       }
     }' -f owner="$owner" -f repo="$repo" -F pr=$pr_number
   ```

2. **Auto-detect already addressed issues** (for unresolved comments):
   - Check if files mentioned in comments were modified in recent commits
   - Look for relevant keywords in commit messages
   - Read current file state and compare with comment context
   - Flag as "Possibly Already Addressed" if detected

3. **Categorize by priority** (only unresolved comments):
   - 🚨 **Critical**: Security, bugs, breaking changes (MUST address)
   - ⚠️ **Important**: Performance, architecture violations (SHOULD address)
   - 💡 **Suggestions**: Readability, best practices (NICE to address)
   - ❓ **Questions**: Discussions, clarifications (REQUIRE response)
   - ✅ **Praise**: Positive feedback (ACKNOWLEDGE)
   - 🔍 **Possibly Addressed**: Already fixed in recent commits (VERIFY)

4. **Present organized summary**:

```
## Review Comments for PR #123: Add user authentication

Found 6 unresolved comment threads (4 already resolved, skipped):

### Critical Issues (require action)
1. 🚨 src/auth.ts:42 - SQL injection vulnerability
   By: @reviewer | Created: 2 hours ago
   "This query is vulnerable to SQL injection..."
   [Suggested action: Implement parameterized query]

### Questions/Discussions
2. ❓ src/config.ts:12 - Why polling instead of webhooks?
   By: @reviewer | Created: 1 hour ago
   "Is there a reason for polling?..."
   [Suggested action: Reply with explanation]

### Suggestions
3. 💡 src/utils.ts:55 - Variable naming
   By: @reviewer | Created: 30 mins ago
   "Consider renaming `d` to `userProfiles`..."
   [Suggested action: Apply suggestion]

### Praise
4. ✅ src/feature.ts:100 - Great implementation
   By: @reviewer | Created: 15 mins ago
   [Suggested action: Acknowledge with emoji]

### Possibly Already Addressed
5. 🔍 src/auth.ts:30 - Missing error handling
   By: @reviewer | Created: 3 days ago
   [Note: File modified in abc123f "fix: add null checks"]
   [Suggested action: Verify and reply if already fixed]

---
How would you like to proceed?
1. Address all comments automatically (where possible)
2. Go through comments one-by-one interactively
3. Address specific files only
4. Skip and just view comments
```

### Phase 4: Interactive Comment Addressing

For each comment, present the context and options:

```
Comment 1/6: src/auth.ts:42 - SQL injection vulnerability
---
"This query is vulnerable to SQL injection. Use parameterized queries instead."

🔍 Smart Check: Analyzing if this might already be addressed...
   - File last modified: 2 days ago (commit def456g)
   - Commit message: "fix: add parameterized queries to auth"
   - Current code shows parameterized queries in use
   ⚠️ This appears to already be fixed! Consider option [8].

Current code:
```typescript
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
```

GitHub suggestion (if available):
```suggestion
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
```

Actions:
[1] Apply suggested fix (implement the change)
[2] Show me the file and I'll fix it manually
[3] Reply to reviewer (ask question or provide explanation)
[4] Reject - out of scope for this PR
[5] Reject - doesn't make sense / disagree
[6] Skip for now (defer decision)
[7] Acknowledge with emoji (for praise only)
[8] Already addressed - reply to confirm

Your choice (1-8):
```

### Phase 5: Handle User Selection

**[1] Apply suggested fix**:
- Extract and apply GitHub suggestion block if available, otherwise implement based on comment
- Show diff for user confirmation
- For critical bugs (🚨): Prompt to add test case
- Create focused commit with descriptive message
- Get commit SHA for reply

**[2] Manual fix**:
- Read and display file with context (±10 lines around mentioned line)
- User makes changes using available tools
- Show diff for confirmation
- For critical bugs (🚨): Prompt to add test case
- Create focused commit

**[3] Reply to reviewer**:
- Prompt: "What would you like to say?"
- Post reply via GitHub API
- Do NOT mark as resolved (let reviewer verify)

**[4] Reject - out of scope**:
- Prompt for reason (optional, provide smart default)
- Post polite reply: "Valid point, but out of scope for this PR which focuses on [objective]"
- Offer to create follow-up issue
- Do NOT mark as resolved

**[5] Reject - disagree**:
- Prompt for technical explanation
- Post respectful reply with reasoning
- Encourage discussion
- Do NOT mark as resolved (let reviewer respond)

**[6] Skip for now**:
- Add to "deferred" list
- Continue to next comment

**[7] Acknowledge (praise)**:
- Post emoji reaction (👍 or 🙏) or simple thank you
- Only for positive comments

**[8] Already addressed**:
- Verify the fix is in place by reading current file
- Find the commit that addressed it
- Post reply with commit SHA reference

### Phase 6: Implement Changes

**For each approved change**:

1. Apply the code change using appropriate tools
2. Show diff to user for verification
3. For critical bugs (🚨), prompt for test case:
   ```
   Should we add a test case for this fix? (recommended for bug fixes)
   - Helps prevent regressions
   - Documents expected behavior
   - Increases reviewer confidence
   ```
4. Create focused commit:
   ```bash
   git add [files]
   git commit -m "fix: address review - [brief description]
   
   Addresses comment by @reviewer on [file]:[line]
   - [What was changed]
   - [Why it was changed]
   [+ with test case]"
   ```
5. Get commit SHA: `commit_sha=$(git rev-parse --short HEAD)`

**Batching strategy**:
- Group related changes in the same file into one commit
- Keep unrelated changes separate
- Include test cases in the same commit as the fix

### Phase 7: Post Direct Thread Replies

**PRIMARY APPROACH**: Reply directly to each review comment thread.

```bash
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# For each comment, post a direct reply to the thread
# Use GraphQL API for reliable thread replies
gh api graphql -f query='
  mutation($subjectId: ID!, $body: String!) {
    addPullRequestReviewComment(input: {
      pullRequestReviewId: $subjectId,
      body: $body
    }) {
      comment {
        id
      }
    }
  }' -f subjectId="$review_thread_id" -f body="$reply_body"
```

**Alternative using REST API** (may have reliability issues):

```bash
# Try REST API first, fall back to GraphQL if it fails
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Method 1: Reply to review comment thread (preferred)
gh api "repos/${repo_info}/pulls/${pr_number}/comments/${comment_id}/replies" \
  --method POST \
  --field body="$reply_body" 2>/dev/null

# Method 2: If above fails, use pr review comment API
if [ $? -ne 0 ]; then
  gh api "repos/${repo_info}/pulls/${pr_number}/comments" \
    --method POST \
    --field body="$reply_body" \
    --field commit_id="$latest_commit_sha" \
    --field path="$file_path" \
    --field in_reply_to="$comment_id"
fi
```

**Fallback approach** (only if direct replies consistently fail):

Post a single comprehensive PR comment as a last resort - but this should NOT be the default approach.

**Reply Templates** (for direct thread replies):

**For implemented fixes**:
```markdown
✅ **Addressed**

Implemented your suggestion - changed to use parameterized queries to prevent SQL injection.

Fixed in commit: abc123f

---
*🤖 Generated by OpenCode*
```

**For already addressed**:
```markdown
✅ **Already Addressed**

This was fixed in commit abc123f: "fix: add parameterized queries to auth"

The code now uses parameterized queries as suggested. Thanks for catching this!

---
*🤖 Generated by OpenCode*
```

**For questions/explanations**:
```markdown
💬 **Response**

Good question! We're using polling here because of firewall restrictions in the customer's environment that prevent webhook delivery. This was discussed in JIRA-1234.

Happy to explore webhooks again once those restrictions are lifted.

---
*🤖 Generated by OpenCode*
```

**For out of scope**:
```markdown
❌ **Out of Scope**

This is a valid point, but it's outside the scope of this PR which focuses on fixing the authentication bug.

I've created issue #456 to track this improvement for a future PR.

---
*🤖 Generated by OpenCode*
```

**For disagreements**:
```markdown
💭 **Different Approach**

I understand your concern, but I think the current approach is preferable here because:
- [Technical reason 1]
- [Technical reason 2]

The alternative you suggested would [explain tradeoff]. Happy to discuss further if you have additional concerns.

---
*🤖 Generated by OpenCode*
```

**For praise**:
```markdown
🙏

---
*🤖 Generated by OpenCode*
```

**Important Notes**:
- NEVER mark conversations as resolved via API. Let reviewers verify and resolve.
- Always attempt direct thread replies first - this is the preferred approach.
- Keep replies concise and focused on the specific comment.
- Include commit SHA references for easy verification.
- Only fall back to comprehensive PR comments if direct replies consistently fail.

### Phase 8: Push Changes

After all commits are created:

```bash
git push origin HEAD
echo "✅ Pushed ${commit_count} commits addressing review comments"
```

### Phase 9: Verify CI/Tests Pass

**CRITICAL**: After pushing changes, verify CI checks to ensure no regressions were introduced.

```bash
# Wait for checks to start (give GitHub Actions time to trigger)
echo "⏳ Waiting for CI checks to start..."
sleep 10

# Check CI status
echo "=== Checking CI status ==="
gh pr checks $pr_number --watch

# Get list of failed checks
failed_checks=$(gh pr checks $pr_number --json name,conclusion,detailsUrl -q '.[] | select(.conclusion == "FAILURE") | {name, url: .detailsUrl}')

if [ -n "$failed_checks" ]; then
  echo "⚠️ CI checks failed after addressing comments"
  echo ""
  echo "Failed checks:"
  echo "$failed_checks" | jq -r '"- " + .name'
  echo ""
  echo "=== Analyzing failures to determine if related to your changes ==="
  echo ""
  
  # Present failed checks to user for analysis
  # User must determine if failures are related to their changes
  echo "Please review the failed checks:"
  echo "$failed_checks" | jq -r '"\(.name): \(.url)"'
  echo ""
  echo "❓ Are these failures related to your changes?"
  echo ""
  echo "[1] Yes - my changes broke these tests (I need to fix them)"
  echo "[2] No - these are unrelated/flaky tests (safe to proceed)"
  echo "[3] Unsure - let me investigate the logs"
  echo ""
  read -p "Your choice (1-3): " choice
  
  case $choice in
    1)
      echo ""
      echo "⚠️ ACTION REQUIRED: Fix test failures introduced by your changes"
      echo ""
      echo "Steps:"
      echo "1. Review failed test logs above"
      echo "2. Identify which changes caused the failures"
      echo "3. Fix the issues (update code or tests)"
      echo "4. Commit and push fixes"
      echo "5. Re-run this workflow to verify fixes"
      echo ""
      exit 1
      ;;
    2)
      echo ""
      echo "✅ Proceeding - failures confirmed as unrelated to your changes"
      echo ""
      echo "📝 NOTE: Document this in your PR if needed:"
      echo "   'CI failures in [test names] are pre-existing/unrelated to this PR'"
      ;;
    3)
      echo ""
      echo "🔍 Please investigate the failure logs:"
      echo "$failed_checks" | jq -r '"\(.name): \(.url)"'
      echo ""
      echo "After investigation, re-run this workflow and choose option [1] or [2]"
      exit 1
      ;;
  esac
else
  echo "✅ All CI checks passed!"
fi
```

**Why this matters**:
- Changes made to address review comments might introduce test failures
- Test failures could indicate:
  - Breaking changes to existing functionality
  - Missing test updates for refactored code
  - Edge cases not covered by your changes
  - Integration issues with other components

**However**: Not all CI failures are related to your changes:
- **Pre-existing failures**: Tests that were already failing before your changes
- **Flaky tests**: Tests that fail intermittently due to timing issues
- **Infrastructure issues**: CI environment problems (network, dependencies, etc.)
- **Unrelated changes**: Failures in test suites for code you didn't touch

**What to do if tests fail**:

1. **Investigate the failure**:
   - Check test logs to understand what broke
   - Compare: Did you modify the failing test or related code?
   - Check PR file changes: Are failing tests in files you touched?

2. **Determine if related to your changes**:
   - ✅ **Related**: Failure in code/tests you modified → Fix it
   - ❌ **Unrelated**: Failure in completely different module → Safe to proceed
   - ❓ **Unsure**: Check git blame, ask in PR, or re-run tests

3. **If related, fix the issues**:
   ```bash
   # Fix the code/tests
   git add [files]
   git commit -m "fix: update tests after addressing review comments
   
   - Fixed selector tests to handle new lock pattern
   - Updated provider state tests for budget reset logic"
   
   git push origin HEAD
   ```

4. **If unrelated, document and proceed**:
   - Note in PR comments that failures are pre-existing
   - Optionally create separate issue to track the flaky test
   - Complete the workflow

**Example: Related failure**:
```
❌ Failed: Test BAAS - nodeproxy
Cause: You modified nodeproxy/selector.go and broke SelectProvider test
Action: Fix your code, commit, push
```

**Example: Unrelated failure**:
```
❌ Failed: Test BAAS - core  
Cause: Failure in core/wallet_test.go, but you only touched nodeproxy/
Action: Confirm unrelated, document if needed, proceed
```

### Phase 10: Display Summary

Provide a comprehensive completion report:

```
✅ Review Comments Addressed

**Comments processed**:
- 🔍 Found: 11 total review comments
- ✅ Already resolved: 4 comments (skipped)
- 📝 Processed: 7 unresolved comments

**Actions taken**:
- ✅ Implemented: 3 comments
- 🔍 Already addressed: 1 comment
- 💬 Replied: 1 comment
- 🙏 Acknowledged: 1 comment
- ❌ Rejected (out of scope): 1 comment
- 💭 Rejected (disagreed): 0 comments
- ⏭️ Skipped: 0 comments

**Commits created**: 3
- abc123f: fix: address SQL injection vulnerability in auth (+ tests)
- def456g: refactor: implement batch query for user posts
- ghi789h: refactor: improve variable naming in utils

**Replies posted**: 7 direct thread replies
- All comments received inline responses with commit references
- Reviewers will be notified of your replies on each thread

**CI Status**: ✅ Verified (all passing or failures confirmed unrelated)
- Checked all CI results after changes
- No regressions introduced by review comment fixes

**Next steps**:
- All unresolved comments have been addressed
- All changes have been pushed to remote
- CI checks verified (passing or unrelated failures documented)
- Ready for re-review from reviewers

View PR: [PR_URL]
```

### Phase 11: Cleanup

**CRITICAL**: If worktree was created, clean it up:

```bash
if [ "$use_worktree" = true ]; then
  cd - > /dev/null
  git worktree remove "$worktree_dir" --force
  echo "=== Cleaned up worktree ==="
fi
```

## Advanced Features

### Smart Suggestion Detection

Detect and extract GitHub suggestion blocks:
```markdown
```suggestion
const query = 'SELECT * FROM users WHERE id = ?';
```
```

Apply these directly at the specified line number.

### Batch Operations

For non-controversial changes:
```
Apply all simple suggestions? (y/n)
- ✅ Variable renaming (3 comments)
- ✅ Import organization (2 comments)
- ⏭️ Skipping architectural changes (requires discussion)
```

### Conflict Detection

Before applying changes:
- Check if file was modified since comment was made
- Verify line numbers haven't shifted
- Warn if code context has changed

## Error Handling

Handle common scenarios gracefully:
- **No PR found**: Ask user for PR URL
- **No unresolved comments**: Inform user all comments are resolved or addressed
- **All comments resolved**: Display count and congratulate, no action needed
- **Comment line missing**: Show current file state and note code may have changed
- **Push fails**: Check for conflicts, suggest pulling
- **Permission errors**: Check `gh auth` scopes
- **Worktree fails**: Clean up and retry
- **Git conflicts**: Guide through manual resolution
- **Inline reply API fails**: Try GraphQL API, then REST API, and only use comprehensive PR comment as last resort
- **JSON parsing errors with --input**: Use `-F field=@file` or `-f field=value` instead
- **Multi-line body escaping issues**: Write to temp file and use `--body-file` or `-F body=@file`
- **GraphQL query for resolved threads fails**: Fall back to processing all comments, rely on "already addressed" detection
- **Worktree state stale**: Detect and reset to latest remote commit (see Phase 1)

## Communication Best Practices

- **Always reply** when addressing comments (even brief "Fixed ✅")
- **Be professional** when disagreeing - focus on technical merits
- **Include commit SHA** in fix replies for easy verification
- **Offer alternatives** when rejecting (e.g., follow-up issues)
- **Ask clarifying questions** if comments are unclear
- **Stay on topic** - redirect off-topic items appropriately
- **Use direct thread replies** as the primary method - reviewers get notifications and context
- **Keep replies concise** and focused on the specific comment

## Code Quality Standards

- **Review before committing**: Always show diff for confirmation
- **Keep commits focused**: One logical change per commit
- **Write descriptive commit messages**: Reference reviewer and location
- **Add test cases for bug fixes**: Prevent regressions (CRITICAL for 🚨)
- **Run linters/tests** before pushing
- **Verify all tests pass** after changes

## Testing Strategy for Bug Fixes

For critical bugs (🚨):
1. Write a failing test that reproduces the bug
2. Apply the fix to make test pass
3. Commit both together (test + fix)
4. Mention test in reply: "Fixed in commit abc123f (with test case)"

Example:
```go
func TestNoPanicWithSingleProvider(t *testing.T) {
    // Reproduces the bug from review comment
    manager := NewManager(/* single provider config */)
    provider, err := manager.SelectProvider(session)
    assert.NoError(t, err)
    assert.NotNil(t, provider)
}
```

## Success Criteria

A successful session achieves:
- ✅ All critical comments addressed or explicitly deferred with solid reasoning
- ✅ Test cases added for all bug fixes (especially critical)
- ✅ Direct replies posted to each review thread with commit SHAs
- ✅ Out-of-scope comments professionally rejected with follow-up issues
- ✅ Disagreements explained with technical reasoning
- ✅ Focused, well-described commits
- ✅ **All CI checks verified** (passing or unrelated failures documented)
- ✅ Changes pushed successfully
- ✅ Clear summary of remaining work (in terminal output)
- ✅ Worktree cleaned up (if used)
- ✅ Reviewers have clear visibility into what was addressed and how

## Pre-merge Checklist

Before requesting re-review:
- [ ] All 🚨 critical comments addressed or rejected with strong justification
- [ ] All bug fixes have test cases
- [ ] **All CI checks verified (passing or unrelated failures documented)**
- [ ] Linter passes
- [ ] All comments have direct thread replies with commit references
- [ ] Out-of-scope items politely rejected with follow-up issues
- [ ] Disagreements explained respectfully with technical reasoning
- [ ] Remaining unaddressed comments documented with reasons
- [ ] Praise acknowledged

---

**Remember**: Review comments are opportunities to improve code quality and learn from others. Address them thoughtfully, communicate clearly, and maintain professional relationships with your reviewers.

---
name: git:review-pr-v3
description: Comprehensive educational code review workflow
---

# Review GitHub Pull Request (v3)

Perform thorough, context-aware, educational code reviews with multi-phase analysis.

## Usage

```bash
# Review specific PR by URL
/git:review-pr-v3 https://github.com/owner/repo/pull/123

# Review PR for current branch (auto-detect)
/git:review-pr-v3
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

## Workflow Overview

The review workflow consists of **7 sequential phases**:

### Phase 1: Setup & PR Detection
**Sequential** - Must complete before proceeding

**Tasks**:

```bash
# 1. Extract PR number from URL argument OR detect from current branch
if [ -n "$1" ]; then
  # Option A: PR number from URL argument
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  use_worktree=true
else
  # Option B: PR for current branch (auto-detect)
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
  use_worktree=false
fi

if [ -z "$pr_number" ]; then
  echo "ERROR: No PR found. Provide URL or ensure current branch has a PR."
  exit 1
fi

# 2. Create git worktree for isolation (if reviewing from URL)
if [ "$use_worktree" = true ]; then
  worktree_path=".worktree/pr-review-${pr_number}"
  # Get PR branch name
  pr_branch=$(gh pr view "$pr_number" --json headRefName -q .headRefName)
  
  # Create worktree
  git fetch origin "$pr_branch"
  git worktree add "$worktree_path" "origin/$pr_branch"
  cd "$worktree_path"
fi

# 3. Validate PR exists and is accessible
gh pr view "$pr_number" --json title,state || {
  echo "ERROR: Cannot access PR #$pr_number"
  exit 1
}
```

**Error Handling**:
- No PR found → Ask user for PR URL
- Invalid URL → Show expected format: `https://github.com/owner/repo/pull/123`
- Worktree creation fails → Check branch exists, fetch if needed

**Output**: `$pr_number`, `$worktree_path` (if created), `$use_worktree` flag

---

### Phase 2: Information Gathering
**Execute all 5 tasks in parallel**

**Tasks**:
1. Fetch PR metadata: `gh pr view "$pr_number" --json title,body,author,state,isDraft,labels`
2. Fetch files changed: `gh pr view "$pr_number" --json files`
3. Fetch PR diff: `gh pr diff "$pr_number"`
4. Fetch review history via GraphQL for PR #$pr_number (detect existing OpenCode reviews)
5. Determine review mode based on review history

**Estimated Time**: ~2-3s (parallel) vs ~10s (sequential)

**Output**: PR metadata, files changed, diff, review threads, suggested review mode

---

### Phase 3: Context Gathering
**Execute in 2 groups: Group A (3 tasks) in parallel, then Group B (2 tasks) in parallel**

**Group A Tasks**:
1. Parse PR description for intent/constraints
2. Search codebase for similar patterns (count occurrences)
3. Check for architectural docs

**Group B Tasks**:
1. Extract explanatory comments from changed files
2. Analyze git history for context

**Estimated Time**: ~5-6s (parallel) vs ~15s (sequential)

**Output**: PR intent, codebase patterns with counts, architectural context, comments, history

---

### Phase 4: Review Mode Selection
**Sequential** - Decision point based on Phase 2 outputs

**Logic**:
```bash
# Analyze review history to determine mode
if [ "$has_previous_opencode_reviews" = false ]; then
  review_mode="first_review"
elif [ "$unresolved_thread_count" -gt 0 ]; then
  review_mode="re_review"
elif [ "$has_new_commits_since_last_review" = true ]; then
  review_mode="incremental_review"
else
  echo "✅ All previous concerns addressed. No new changes to review."
  exit 0
fi
```

**Modes**:
- **first_review**: No previous OpenCode reviews → Comprehensive review (7-10 comments)
- **re_review**: Unresolved threads exist → Verification focused (3 NEW issues max)
- **incremental_review**: All resolved + new commits → Delta only (5 critical issues max)
- **no_review_needed**: All resolved + no new commits → Exit early

**Output**: `$review_mode`, scope boundaries for next phases

---

### Phase 5: Two-Pass Code Analysis
**Pass 1 (parallel): Run all 6 category scans simultaneously**
**Pass 2 (parallel): Assign severity to each finding using context**

**Pass 1 Categories**:
1. Security issues (SQL injection, XSS, auth bypass, etc.)
2. Bugs (null refs, off-by-one, race conditions, etc.)
3. Performance (N+1 queries, inefficient loops, memory leaks, etc.)
4. Architecture (coupling, responsibility violations, etc.)
5. Testing (missing tests, inadequate coverage, etc.)
6. Readability (naming, complexity, unclear logic, etc.)

**Pass 2 Severity Assignment**:
- Use context from Phase 3 (patterns, intent, comments)
- Assign confidence-based severity (critical, major, minor, info)
- Consider: frequency in codebase, PR intent, existing patterns

**Estimated Time**: ~10-15s (parallel) vs ~60s (sequential)

**Output**: Categorized findings with confidence-based severity

---

### Phase 6: Comment Filtering & Posting
**Apply mode-specific limits and post review**

**Comment Limits**: Enforced based on selected review mode from Phase 4

**Filtering Steps**:
1. Remove intentional patterns (e.g., if codebase has 50+ string concatenations, don't flag one more)
2. Remove out-of-scope comments (unchanged code, unrelated files)
3. Sort by severity (critical → major → minor → info)
4. Apply mode-specific limit
5. Format with educational explanations

**Posting Methods**:
- **first_review / incremental_review**: `gh pr review "$pr_number" --comment --body "$(cat review.md)"`
- **re_review**: Reply in-thread, mark resolved via GraphQL, post verification summary

**Re-Review Specific Process**:
1. Fetch unresolved OpenCode threads via GraphQL for PR #$pr_number
2. Verify each fix by reading current code
3. Reply in-thread with verification result
4. Mark resolved via GraphQL if truly fixed
5. Post verification summary comment

**Output**: Posted review/verification confirmation

---

### Phase 7: Cleanup
**Sequential** - Final teardown

**Tasks**:

```bash
# 1. Remove worktree (if created)
if [ "$use_worktree" = true ]; then
  # Return to original directory first
  cd - > /dev/null
  
  # Remove worktree
  git worktree remove "$worktree_path" --force 2>/dev/null || {
    echo "WARNING: Failed to remove worktree at $worktree_path"
    echo "Manual cleanup: git worktree remove $worktree_path --force"
  }
fi

# 2. Report success/failure status
echo "✅ Review complete for PR #$pr_number"
```

**Output**: Cleanup confirmation

---

## Performance Optimization

Execute tasks in parallel where possible to achieve significant time savings:

| Phase | Sequential | Parallel | Improvement |
|-------|-----------|----------|-------------|
| Phase 2: Info Gathering | ~10s | ~3s | 70% faster |
| Phase 3: Context Gathering | ~15s | ~6s | 60% faster |
| Phase 5: Code Analysis | ~60s | ~15s | 75% faster |
| **Total** | **~85-90s** | **~20-25s** | **70-75% faster** |

**Key Insight**: Phases 2, 3, and 5 contain I/O-bound and CPU-bound tasks that can run concurrently.

---

## Example Execution Flows

### Example 1: First Review (with URL argument)

```bash
# User runs: /git:review-pr-v3 https://github.com/org/repo/pull/123

# Phase 1: Setup
# Script receives $1 = "https://github.com/org/repo/pull/123"
pr_number=123  # Extracted from $1
use_worktree=true
worktree_path=".worktree/pr-review-123"
# Create worktree, validate PR

# Phase 2: Information gathering (parallel execution)
# Execute: metadata fetch, files fetch, diff fetch, review history, mode detection
# Receive: metadata, files, diff, threads, mode="first_review"

# Phase 3: Context gathering (parallel execution)
# Execute: parse intent, search patterns, check docs, extract comments, analyze history
# Receive: intent, patterns={sql_concat: 12 occurrences}, docs, comments

# Phase 4: Select mode
REVIEW_MODE="first_review"  # No previous reviews

# Phase 5: Code analysis (parallel execution)
# Execute: 6 category scans in parallel, then severity assignment in parallel
# Receive: 17 findings with severity assignments

# Phase 6: Filter & post
# Execute: apply limit (7-10), filter, format, post
# Receive: "Posted 7 comments with review summary"

# Phase 7: Cleanup
cd - > /dev/null
git worktree remove "$worktree_path" --force
echo "✅ Review complete for PR #$pr_number"
```

### Example 2: Re-Review (auto-detect from current branch)

```bash
# User runs: /git:review-pr-v3 (from PR branch)
# Script receives $1 = "" (empty)

# Phase 1: Detect PR from branch
pr_number=456  # Auto-detected via gh pr view
use_worktree=false  # Already on the branch
# No worktree created

# Phase 2: Information gathering reveals 3 unresolved threads
REVIEW_MODE="re_review"

# Phase 3: Skip (not needed for re-review)

# Phase 4: Confirmed re-review mode

# Phase 5: Skip full analysis

# Phase 6: Verification
# Execute: fetch unresolved threads, verify fixes, post replies, mark resolved
# Receive: "Verified 3 fixes, posted verification summary"

# Phase 7: Cleanup (no worktree to remove)
echo "✅ Review complete for PR #$pr_number"
```

---

## GitHub CLI Commands Reference

### PR Information
```bash
# Get PR metadata
gh pr view "$pr_number" --json title,body,author,state,isDraft,labels

# Get files changed
gh pr view "$pr_number" --json files

# Get PR diff
gh pr diff "$pr_number"

# Get PR branch name
gh pr view "$pr_number" --json headRefName -q .headRefName
```

### Review History (GraphQL)
```bash
# Fetch review threads with resolution status
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviews(last: 100) {
          nodes {
            author { login }
            body
            createdAt
            comments(first: 100) {
              nodes {
                body
                path
                line
                isResolved
              }
            }
          }
        }
      }
    }
  }
' -f owner="$owner" -f repo="$repo" -F number="$pr_number"
```

### Posting Reviews
```bash
# Post review comment
gh pr review "$pr_number" --comment --body "$(cat review.md)"

# Reply to thread (use comment ID from GraphQL)
gh api graphql -f query='
  mutation($id: ID!, $body: String!) {
    addPullRequestReviewComment(input: {pullRequestReviewId: $id, body: $body}) {
      comment { id }
    }
  }
' -f id="$thread_id" -f body="$reply_body"

# Mark thread resolved
gh api graphql -f query='
  mutation($id: ID!) {
    resolveReviewThread(input: {threadId: $id}) {
      thread { isResolved }
    }
  }
' -f id="$thread_id"
```

### Git Worktree
```bash
# Create worktree
git worktree add "$worktree_path" "origin/$pr_branch"

# Remove worktree
git worktree remove "$worktree_path" --force
```

---

## Comment Templates

### Educational Review Comment Format
```markdown
**[Category]**: Issue summary

**Why this matters**: Educational explanation of the impact

**Example**:
\`\`\`language
// Current approach
[problematic code]

// Recommended approach
[better code]
\`\`\`

**Resources**: [Link to docs/best practices]
```

### Verification Reply Format
```markdown
✅ **Verified**: [Issue resolved]
- [Specific change made]
- [Why it fixes the issue]

OR

⚠️ **Not fully addressed**: [Remaining concern]
- [What's still needed]
```

### Review Summary Format
```markdown
## OpenCode Review Summary

**Mode**: [first_review | re_review | incremental_review]
**Comments**: X findings (Y critical, Z major)

### Key Findings
1. [Category]: [Brief summary]
2. [Category]: [Brief summary]

**Note**: This is an educational review. Human approval required.
```

---

## Error Handling

### Common Errors & Solutions

**Error**: No PR found
- **Solution**: Provide URL or ensure current branch has a PR

**Error**: Invalid URL format
- **Solution**: Use format `https://github.com/owner/repo/pull/123`

**Error**: Worktree creation fails
- **Solution**: Check branch exists, run `git fetch origin "$pr_branch"`

**Error**: GraphQL rate limit
- **Solution**: Wait 60 seconds, retry with exponential backoff

**Error**: Cannot post review
- **Solution**: Check GitHub token permissions (`gh auth status`)

---

## Success Criteria

### Phase Completion Checks

**Phase 1**: ✅ `$pr_number` extracted, worktree created (if needed), PR validated
**Phase 2**: ✅ Metadata, files, diff, review history fetched
**Phase 3**: ✅ Intent parsed, patterns counted, context gathered
**Phase 4**: ✅ Review mode selected with clear rationale
**Phase 5**: ✅ Findings categorized with severity assigned
**Phase 6**: ✅ Comments posted within mode limits
**Phase 7**: ✅ Worktree removed (if created), success message displayed

### Quality Checks

- **Educational Value**: Every comment explains WHY, not just WHAT
- **Accuracy**: No false positives from intentional patterns
- **Scope**: Comments only on changed code (unless architectural)
- **Actionability**: Each finding includes recommended fix
- **Tone**: Professional, respectful, educational

---

## Agent Capabilities Reference

Any agent executing this command should:

1. **Execute tasks in parallel** where indicated (Phases 2, 3, 5)
2. **Use GitHub CLI** for all GitHub operations
3. **Format comments** with educational explanations
4. **Apply filters** to remove false positives
5. **Respect mode limits** for comment counts
6. **Clean up resources** (worktrees) when done
7. **Handle errors** gracefully with clear messages

For detailed examples of each capability, see the Example Execution Flows section above.

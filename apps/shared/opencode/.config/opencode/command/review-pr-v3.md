---
name: git:review-pr-v3
description: Comprehensive educational code review using pr-reviewer agent
---

# Review GitHub Pull Request (v3) - Orchestration Playbook

This command orchestrates the pr-reviewer agent through a multi-phase workflow to perform thorough, context-aware, educational code reviews.

## Usage

```bash
# Review specific PR by URL
/git:review-pr-v3 https://github.com/owner/repo/pull/123

# Review PR for current branch (auto-detect)
/git:review-pr-v3
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

## Architecture

- **This file**: High-level orchestration playbook (WHEN to invoke agent, WHAT context to provide)
- **pr-reviewer agent**: Implementation details (HOW to execute tasks, GitHub CLI commands, templates)

## Workflow Overview

The review workflow consists of **7 sequential phases**. Each phase invokes the pr-reviewer agent with specific instructions and context.


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
**Invoke pr-reviewer agent** with parallelization instructions

**Agent Invocation**:
```
Task: Execute Phase 2 - Information Gathering
Context: PR #$pr_number
Instructions: Execute all 5 tasks in parallel (see pr-reviewer.md Phase 2)
Expected Output: PR metadata, files changed, diff, review threads, suggested review mode
```

**What the agent will do** (see pr-reviewer.md for implementation details):
- Fetch PR metadata: `gh pr view "$pr_number" --json title,body,author,state,isDraft,labels`
- Fetch files changed: `gh pr view "$pr_number" --json files`
- Fetch PR diff: `gh pr diff "$pr_number"`
- Fetch review history via GraphQL for PR #$pr_number
- Detect review mode based on existing OpenCode reviews

**Estimated Time**: ~2-3s (parallel) vs ~10s (sequential)

**Output**: Receive structured data from agent → Use to determine Phase 4 mode selection

---

### Phase 3: Context Gathering
**Invoke pr-reviewer agent** with parallelization instructions

**Agent Invocation**:
```
Task: Execute Phase 3 - Context Gathering
Context: PR diff from Phase 2
Instructions: Execute Group A (3 tasks) in parallel, then Group B (2 tasks) in parallel
Expected Output: PR intent, codebase patterns with counts, architectural context, comments, history
```

**What the agent will do** (see pr-reviewer.md for implementation details):
- Parse PR description for intent/constraints
- Search codebase for similar patterns (count occurrences)
- Check for architectural docs and explanatory comments

**Estimated Time**: ~5-6s (parallel) vs ~15s (sequential)

**Output**: Context data → Use in Phase 5 for severity assignment

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

**Mode Descriptions**:
- **first_review**: No previous OpenCode reviews → Comprehensive review
- **re_review**: Unresolved threads exist (isResolved: false) → Verification focused
- **incremental_review**: All resolved + new commits → Delta only
- **no_review_needed**: All resolved + no new commits → Exit early

**Output**: `$review_mode`, scope boundaries for next phases

---

### Phase 5: Two-Pass Code Analysis
**Invoke pr-reviewer agent** with review mode and context

**Agent Invocation**:
```
Task: Execute Phase 5 - Two-Pass Code Analysis
Context: 
  - Review Mode: $review_mode
  - PR Number: $pr_number
  - PR Diff: [from Phase 2]
  - Context Data: [from Phase 3]
Instructions: 
  - Pass 1: Run all 6 category scans in parallel
  - Pass 2: Assign severity to each finding in parallel using context
Expected Output: Categorized findings with confidence-based severity
```

**What the agent will do** (see pr-reviewer.md for implementation details):
- Pass 1: Scan for patterns in 6 categories (security, bugs, performance, etc.)
- Pass 2: Assign severity based on context (codebase patterns, PR description, comments)

**Estimated Time**: ~10-15s (parallel) vs ~60s (sequential)

**Output**: Findings list with severity → Filter in Phase 6

---

### Phase 6: Comment Filtering & Posting
**Invoke pr-reviewer agent** with findings and mode limits

**Agent Invocation**:
```
Task: Execute Phase 6 - Comment Filtering & Posting
Context:
  - Review Mode: $review_mode
  - PR Number: $pr_number
  - Findings: [from Phase 5]
  - Comment Limits: [first_review: 7-10, re_review: 3, incremental_review: 5]
Instructions: Filter, format, and post comments per mode requirements
Expected Output: Posted review confirmation
```

**What the agent will do** (see pr-reviewer.md for implementation details):
- Apply comment limits based on $review_mode
- Filter out intentional patterns and out-of-scope comments
- Format with educational explanations
- Post using appropriate GitHub CLI method for PR #$pr_number

**Re-Review Mode** (when $review_mode = "re_review"):
- Fetch unresolved OpenCode threads via GraphQL for PR #$pr_number
- Verify each fix by reading current code
- Reply in-thread with verification
- Mark resolved via GraphQL if truly fixed
- Post verification summary

**Output**: Posted review/verification

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

## Review Modes (Agent Behavior)

The agent adapts its behavior based on the mode selected in Phase 4:

### First Review
- **Scope**: Entire PR diff
- **Comment Limit**: 7-10 meaningful comments
- **Focus**: All categories (security, bugs, performance, architecture, testing, readability)
- **Approval**: NEVER directly approve - leave to human

### Re-Review
- **Scope**: Unresolved threads (`isResolved: false`) + new commits
- **Comment Limit**: 3 NEW issues only (verification doesn't count)
- **Focus**: Verify fixes, find new critical issues
- **Process**: Reply in-thread, mark resolved via GraphQL, post summary
- **Approval**: NEVER directly approve - leave to human

### Incremental Review
- **Scope**: ONLY delta since last review (`git diff <last_sha>..HEAD`)
- **Comment Limit**: 5 comments on critical issues only
- **Focus**: Critical issues in new code (more lenient than first review)
- **Approval**: NEVER directly approve - leave to human

### No Review Needed
- **Trigger**: All resolved + no new commits
- **Action**: Exit with message "✅ All concerns addressed. No new changes to review."

---

## Performance Optimization

By invoking the agent with parallel execution instructions, we achieve significant time savings:

| Phase | Sequential | Parallel | Improvement |
|-------|-----------|----------|-------------|
| Phase 2: Info Gathering | ~10s | ~3s | 70% faster |
| Phase 3: Context Gathering | ~15s | ~6s | 60% faster |
| Phase 5: Code Analysis | ~60s | ~15s | 75% faster |
| **Total** | **~85-90s** | **~20-25s** | **70-75% faster** |

**Key Insight**: Phases 2, 3, and 5 contain I/O-bound and CPU-bound tasks that can run concurrently. The agent knows how to execute these in parallel when instructed.

---

## Example Orchestration Flow

### Example 1: First Review (with URL argument)

```bash
# User runs: /git:review-pr-v3 https://github.com/org/repo/pull/123

# Phase 1: Setup
# Script receives $1 = "https://github.com/org/repo/pull/123"
pr_number=123  # Extracted from $1
use_worktree=true
worktree_path=".worktree/pr-review-123"
# Create worktree, validate PR

# Phase 2: Invoke agent for information gathering
invoke_agent(
  task="Execute Phase 2 - Information Gathering",
  context={ pr_number: "$pr_number" },
  parallel=true
)
# Receive: metadata, files, diff, threads, mode="first_review"

# Phase 3: Invoke agent for context gathering
invoke_agent(
  task="Execute Phase 3 - Context Gathering",
  context={ diff: [...] },
  parallel=true
)
# Receive: intent, patterns={sql_concat: 12 occurrences}, docs, comments

# Phase 4: Select mode
REVIEW_MODE="first_review"  # No previous reviews

# Phase 5: Invoke agent for code analysis
invoke_agent(
  task="Execute Phase 5 - Two-Pass Code Analysis",
  context={ mode: "first_review", diff: [...], patterns: {...} },
  parallel=true
)
# Receive: 17 findings with severity assignments

# Phase 6: Invoke agent for filtering & posting
invoke_agent(
  task="Execute Phase 6 - Comment Filtering & Posting",
  context={ mode: "first_review", findings: [...], limit: 7-10 }
)
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

# Phase 6: Invoke agent for verification
invoke_agent(
  task="Execute Phase 6 - Re-Review Verification",
  context={ mode: "re_review", pr_number: "$pr_number" }
)
# Agent fetches unresolved threads, verifies fixes, posts replies, marks resolved

# Phase 7: Cleanup (no worktree to remove)
echo "✅ Review complete for PR #$pr_number"
```

---

## Agent Capabilities Reference

For implementation details on HOW the agent executes each phase, see:
- **Phase execution instructions**: apps/shared/opencode/.config/opencode/agent/pr-reviewer.md (Phase Execution Instructions section)
- **GitHub CLI commands**: apps/shared/opencode/.config/opencode/agent/pr-reviewer.md (GitHub CLI Commands Reference section)
- **Comment templates**: apps/shared/opencode/.config/opencode/agent/pr-reviewer.md (Comment Templates section)
- **Error handling**: apps/shared/opencode/.config/opencode/agent/pr-reviewer.md (Error Handling section)
- **Success criteria**: apps/shared/opencode/.config/opencode/agent/pr-reviewer.md (Success Criteria section)

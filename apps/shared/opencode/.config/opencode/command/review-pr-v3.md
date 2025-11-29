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

The review workflow consists of **6 sequential phases**:

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

### Phase 4: Two-Pass Code Analysis
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

### Phase 5: Comment Filtering & Posting
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

### Phase 6: Cleanup
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
| Phase 4: Code Analysis | ~60s | ~15s | 75% faster |
| **Total** | **~85-90s** | **~20-25s** | **70-75% faster** |

**Key Insight**: Phases 2, 3, and 4 contain I/O-bound and CPU-bound tasks that can run concurrently.

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

# Phase 4: Code analysis (parallel execution)
# Execute: 6 category scans in parallel, then severity assignment in parallel
# Receive: 17 findings with severity assignments

# Phase 5: Filter & post
# Execute: apply limit (7-10), filter, format, post
# Receive: "Posted 7 comments with review summary"

# Phase 6: Cleanup
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

# Phase 4: Skip full analysis

# Phase 5: Verification
# Execute: fetch unresolved threads, verify fixes, post replies, mark resolved
# Receive: "Verified 3 fixes, posted verification summary"

# Phase 6: Cleanup (no worktree to remove)
echo "✅ Review complete for PR #$pr_number"
```

---

## Agent Technical Reference

For detailed GitHub CLI commands, GraphQL queries, and comment templates used by the agent during execution, refer to the pr-reviewer.md agent file:

- **GitHub CLI Commands**: pr-reviewer.md lines 571-792
- **Comment Templates**: pr-reviewer.md lines 793-953
- **Review Philosophy & Principles**: pr-reviewer.md lines 1-450

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

## Phase Completion Criteria

Each phase must complete successfully before proceeding to the next:

**Phase 1 - Setup**: 
- ✅ PR number extracted from URL or auto-detected
- ✅ Worktree created (if reviewing from URL)
- ✅ PR validated and accessible

**Phase 2 - Information Gathering**: 
- ✅ PR metadata fetched (title, body, author, state)
- ✅ Files changed list retrieved
- ✅ PR diff retrieved
- ✅ Review history fetched via GraphQL
- ✅ Review mode determined

**Phase 3 - Context Gathering**: 
- ✅ PR intent and constraints parsed
- ✅ Similar patterns searched (with occurrence counts)
- ✅ Architectural context gathered
- ✅ Explanatory comments extracted
- ✅ Historical context analyzed

**Phase 4 - Code Analysis**: 
- ✅ All 6 category scans completed
- ✅ Severity assigned to all findings using context
- ✅ Findings categorized with confidence scores

**Phase 5 - Comment Filtering & Posting**: 
- ✅ Comments filtered within mode limits
- ✅ Intentional patterns excluded
- ✅ Out-of-scope comments removed
- ✅ Review posted or verification completed

**Phase 6 - Cleanup**: 
- ✅ Worktree removed (if created)
- ✅ Success/failure status reported

---

## Phase Execution Details

### Phase 2: Information Gathering
**Execution Strategy**: Execute all 5 tasks in parallel

**Tasks**:
1. Fetch PR metadata: `gh pr view "$pr_number" --json title,body,author,state,isDraft,labels`
2. Fetch files changed: `gh pr view "$pr_number" --json files`
3. Fetch PR diff: `gh pr diff "$pr_number"`
4. Fetch review history via GraphQL (see pr-reviewer.md for query)
5. Determine review mode based on review history

**Expected Output**: PR metadata, files changed, diff, review threads, suggested review mode

---

### Phase 3: Context Gathering
**Execution Strategy**: Execute in 2 groups

**Group A (parallel)** - No dependencies:
1. Parse PR description for intent, constraints, scope, related issues
2. Search for similar patterns across codebase (grep/ripgrep)
3. Check for architectural docs (ADRs, design docs)

**Group B (parallel after A)** - Needs diff analysis:
4. Check for explanatory comments in changed files
5. Search historical context (related issues/PRs)

**Expected Output**: PR intent, codebase patterns (with occurrence counts), architectural context, explanatory comments, historical decisions

---

### Phase 4: Two-Pass Code Analysis
**Execution Strategy**: Pass 1 (parallel by category), Pass 2 (parallel by finding)

**Pass 1: Pattern Detection (parallel by category)**
1. Security scan (SQL injection, XSS, path traversal)
2. Bug scan (null derefs, off-by-one, race conditions)
3. Performance scan (N+1 queries, memory leaks)
4. Architecture scan (tight coupling, missing abstractions, circular dependencies, poor modularity, unclear boundaries)
5. Testing scan (missing tests, inadequate coverage)
6. Readability scan (magic numbers, unclear names)

**Pass 2: Severity Assignment (parallel by finding)**
For each finding from Pass 1:
1. Check if pattern is common in codebase (from Phase 3 context)
2. Check for explanatory comments (from Phase 3 context)
3. Check PR description for constraints (from Phase 3 context)
4. Assess against known anti-patterns
5. Calculate confidence score
6. Assign severity: 🚨 Critical (>90%) / ⚠️ Important (60-90%) / 💡 Suggestion (40-60%) / ❓ Question (<40%)

**Expected Output**: Categorized findings with confidence-based severity and context justification

---

### Phase 5: Comment Filtering & Posting
**Execution Strategy**: Execute sequentially (must respect limits)

**Tasks**:
1. Apply comment limits based on review mode (First: 7-10, Re-Review: 3, Incremental: 5)
2. Filter out comments on intentional patterns
3. Filter out comments outside PR scope
4. Prioritize by severity
5. Format with educational explanations + code examples
6. Post using appropriate method for review mode

**Re-Review Specific Process**:
1. Fetch unresolved OpenCode threads via GraphQL
2. Verify each fix by reading current code
3. Reply in-thread with verification result
4. Mark resolved via GraphQL if truly fixed
5. Post verification summary comment

**Expected Output**: Posted review confirmation or verification summary

---

## Agent Invocation Protocol

The workflow invokes the pr-reviewer agent for each phase. The agent receives phase-specific instructions and executes tasks autonomously.

### Example: Phase 2 Invocation

```bash
# Invoke agent for Phase 2
/task agent:pr-reviewer "
Execute Phase 2: Information Gathering for PR #${pr_number}

Use the parallelization strategy documented in Phase 2 Execution Details.
Fetch all required data and determine the appropriate review mode.

Return structured output containing:
- pr_metadata
- files_changed
- pr_diff
- review_history
- suggested_mode
"
```

### Example: Phase 4 Invocation

```bash
# Invoke agent for Phase 4
/task agent:pr-reviewer "
Execute Phase 4: Two-Pass Code Analysis for PR #${pr_number}

Input from Phase 3:
- PR intent: ${pr_intent}
- Codebase patterns: ${patterns}
- Architectural context: ${context}

Execute Pass 1 (pattern detection) and Pass 2 (severity assignment) using the context provided.
Apply confidence-based severity rules from pr-reviewer.md.

Return categorized findings with severity and justification.
"
```

### Agent Output Parsing

The agent returns structured data that the workflow uses for subsequent phases:

```bash
# Example: Parsing Phase 2 output
pr_metadata=$(echo "$phase2_output" | jq -r '.pr_metadata')
files_changed=$(echo "$phase2_output" | jq -r '.files_changed')
review_mode=$(echo "$phase2_output" | jq -r '.suggested_mode')

# Use in Phase 3
if [ "$review_mode" = "re_review" ]; then
  # Skip context gathering, go straight to verification
  ...
fi
```

---

## Workflow Success Criteria

**Completion**: 
- ✅ All phases completed successfully
- ✅ Review posted or verification summary provided
- ✅ Worktree cleaned up (if created)

**Quality**: 
- ✅ Review mode correctly selected based on PR state
- ✅ Parallelization applied where specified
- ✅ Phase outputs properly passed to subsequent phases
- ✅ Errors handled gracefully with clear messages

**Review Quality**: See pr-reviewer.md for detailed quality criteria including educational value, accuracy, scope, and tone requirements.

---

## Agent Capabilities Reference

Any agent executing this command should:

1. **Execute tasks in parallel** where indicated (Phases 2, 3, 4)
2. **Use GitHub CLI** for all GitHub operations
3. **Select appropriate review mode** based on PR state (see pr-reviewer.md)
4. **Format comments** with educational explanations
5. **Apply filters** to remove false positives
6. **Respect mode limits** for comment counts
7. **Clean up resources** (worktrees) when done
8. **Handle errors** gracefully with clear messages

For detailed examples of each capability, see the Example Execution Flows section above.

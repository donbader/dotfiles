---
name: git:review-pr
description: Provide comprehensive, educational code review for a GitHub PR
---

# Review GitHub Pull Request

Perform a thorough, educational code review of a GitHub PR with constructive feedback that helps the author learn and improve their code quality.

## Usage

**Command syntax**:
```
/git:review-pr [PR_URL]
```

**Examples**:
```
# Review PR from URL (recommended)
/git:review-pr https://github.com/payfazz/straitsx-blockchain/pull/2944

# Review PR for current branch (auto-detect)
/git:review-pr
```

**Priority**: If you provide a PR URL as argument (`$1`), that URL is used regardless of current branch. Otherwise, the command auto-detects the PR for your current branch using `gh pr view`.

## Review Philosophy

Your review should be:
- **Educational**: Explain WHY something should change, not just WHAT to change
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact line numbers, files, and code patterns
- **Balanced**: Highlight what's done well AND what needs improvement
- **Actionable**: Provide clear next steps the author can take
- **Focused**: Only comment on code within the PR scope
- **Context-aware**: Read and understand the PR description to know the author's intent

**Goal**: The PR author should feel they learned something valuable from your review.

## Core Principles

### 1. Modular Design
Structure your review process in 6 phases:
1. **Data Gathering**: Fetch PR information (metadata, diff, description) - single bash command
2. **Context Analysis**: Read PR description to understand author's intent
3. **Code Analysis**: Read changed files and analyze directly (no Task tool needed)
4. **Issue Identification**: Create focused, educational comments
5. **User Approval**: Present summary for review before posting
6. **Comment Posting**: Post approved comments via GitHub API
7. **Confirmation**: Report success to user

### 2. Stay Within Scope

**Inline Comments** - Only for code changes in this PR:
- Security issues, bugs, breaking changes in changed code
- Performance problems in new code
- Architecture violations in changed code
- Missing tests for new functionality
- Readability issues in changed code

**Summary Comment - "Future Considerations"** - For broader suggestions:
- Refactoring opportunities outside PR scope
- Architecture improvements for future work
- Technical debt to track separately
- Clearly marked as NOT blockers

**Example**:
```
❌ BAD (inline): "This entire UserService should use dependency injection"
   (UserService not changed - creates scope creep)

✅ GOOD (inline): "The new getUserProfile() queries DB directly. Use the existing 
   UserRepository pattern (see getUserById:42) for consistency"
   (getUserProfile() is new - directly relevant)

✅ GOOD (summary): "Future: UserService could benefit from dependency injection 
   to improve testability (not a blocker for this OAuth PR)"
```

### 3. Read PR Description for Context

Always analyze the PR description to understand:
- **What**: Author's stated goal
- **Why**: Motivation for changes
- **Scope**: Hotfix, feature, refactor, or bug fix
- **Constraints**: Known trade-offs or limitations
- **Testing**: Author's testing approach

This prevents commenting on intentional decisions or asking already-answered questions.

## Workflow

### Phase 1: Fetch PR Information (Single Bash Call)

**IMPORTANT**: If user provides a PR URL as `$1`, use that PR **regardless** of current branch. PR URL takes priority.

```bash
# Extract PR number from user-provided URL if given, otherwise use current branch
if [ -n "$1" ]; then
  # User provided explicit PR URL - use this (priority over current branch)
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  echo "=== INFO: Using PR from provided URL (not current branch) ==="
else
  # No URL provided - fall back to current branch
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
fi

if [ -z "$pr_number" ]; then 
  echo "ERROR: No PR found. Provide a PR URL or ensure current branch has a PR."
  exit 1
fi

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== CURRENT_BRANCH ===" && echo "$current_branch" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,headRefName,baseRefName,url && \
echo "=== COMMIT_HISTORY ===" && gh pr view $pr_number --json commits -q '.commits[].commit | "\(.messageHeadline)\n---"' && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- **PR URL takes priority**: If user provides URL, use it even if current branch has different PR
- Chain commands with `;` and `&&` for efficiency
- Use `echo "=== SECTION ==="` markers to parse output
- Extract PR number from URL (format: `https://github.com/owner/repo/pull/123`)
- **Capture PR body/description** - critical for context
- Current branch is captured for info only (may differ from reviewed PR)

**Example scenarios**:
```
Scenario 1: User on branch "feature-a" with PR #100, provides URL to PR #200
→ Review PR #200 (from URL), ignore current branch's PR #100

Scenario 2: User on branch "feature-a" with PR #100, no URL provided
→ Review PR #100 (from current branch)

Scenario 3: User on branch "main" (no PR), provides URL to PR #200
→ Review PR #200 (from URL)
```

### Phase 2: Understand PR Context

**Before analyzing code**, read the PR description to extract:
1. **Purpose**: What is the author trying to achieve?
2. **Scope**: Bug fix, feature, refactor, hotfix, or improvement?
3. **Constraints**: Trade-offs, future work, or technical debt mentioned?
4. **Testing**: What testing approach did they take?

**Example contexts**:
```
"Quick hotfix for production bug - will refactor in JIRA-123"
→ Focus on correctness, not perfect architecture

"Part 1 of 3: Adds data layer only, UI in next PR"  
→ Don't comment on missing UI

"Using polling due to firewall restrictions"
→ Don't suggest webhooks
```

### Phase 3: Analyze Code (Direct Analysis - No Tasks Needed)

**IMPORTANT**: Do NOT use Task tool for code analysis. Analyze the code directly yourself for efficiency.

**Analyze directly**:
1. **Read the PR diff** to identify all changed files and line ranges
2. **Read changed files** to understand full context around modifications
3. **Analyze the changes** for issues in categories below
4. **Only use Task tool** if you need to search for patterns across many files in the codebase

**Analysis categories** (analyze in order of priority):

1. **Security & Bugs** 🚨
   - Security vulnerabilities (SQL injection, XSS, auth bypasses, data leaks)
   - Logic errors, null/undefined handling issues
   - Race conditions, deadlocks, resource leaks
   - Breaking changes to public APIs

2. **Performance** ⚠️
   - N+1 query problems
   - Inefficient algorithms (O(n²) when O(n) exists)
   - Memory leaks, unnecessary allocations
   - Blocking operations in hot paths

3. **Architecture & Design** ⚠️
   - Violations of established patterns (check surrounding code)
   - Separation of concerns issues
   - Missing abstractions or unnecessary coupling
   - Inconsistent error handling

4. **Testing** 💡
   - New functionality without tests
   - Missing edge case coverage
   - Tests that don't match implementation

5. **Readability** 💡
   - Confusing variable names or logic
   - Missing documentation for public APIs
   - Overly complex code that could be simplified

**When to use Task tool** (rarely needed):
```
Only if you need to search for patterns across the codebase to validate a concern:

Example: "I see they're using a custom error handler pattern. Let me check if this 
is consistent with how it's done elsewhere..."

Task: "Search the codebase for existing error handler patterns. Find 2-3 examples 
of how errors are handled in similar controllers. Return file:line references."
```

**Typical flow** (no Tasks needed):
1. Fetch PR info with bash (Phase 1) → get diff
2. Read 3-5 most important changed files directly
3. Analyze code yourself (Phase 3) → identify issues
4. Generate comments (Phase 4)
5. Present for approval (Phase 5)
6. Post via GitHub API (Phase 6)

**Why direct analysis is better**:
- ✅ Faster (no Task overhead)
- ✅ Better context (you already have the diff)
- ✅ More focused (you know what to look for)
- ❌ Task agents add latency and context switching

### Phase 4: Identify Issues (Focus on Changed Code Only)

**Priority Order**:
1. **Critical** 🚨: Security, bugs, breaking changes
2. **Important** ⚠️: Performance, architecture violations
3. **Suggestions** 💡: Readability, documentation

**Guidelines by Category**:

- **Security & Bugs**: Always comment if found
- **Performance**: Comment if significant impact (quantify when possible)
- **Architecture**: Only if violates established patterns (reference existing code)
- **Testing**: Comment if new functionality lacks tests
- **Readability**: Comment sparingly - only truly confusing code
- **Documentation**: Public APIs only
- **Future Improvements**: Save for summary comment's "Future Considerations"

**Apply scope filters**:
- Is this in the diff?
- Within PR's stated purpose?
- Already addressed in description?
- Pre-existing issue unrelated to changes?

**Aim for 3-10 meaningful comments**, not 50+ nitpicks.

### Phase 5: Present Review for Approval

**CRITICAL**: Do NOT post automatically. Present summary to user first.

**Display format**:
```
## Review Summary for PR #[NUMBER]: [Title]

**Found [X] comments**:
- 🚨 [X] Critical (security, bugs)
- ⚠️ [X] Important (performance, architecture)
- 💡 [X] Suggestions (readability, best practices)
- ❓ [X] Questions
- ✅ [X] Praise

**Comments to post**:

1. 🚨 auth.ts:42 - SQL injection vulnerability in login query
2. 🚨 middleware.ts:120 - Missing authorization check for admin routes
3. ⚠️ user-controller.ts:85 - N+1 query problem when fetching user posts
4. ⚠️ auth.ts:200 - Business logic in controller (should be in service)
5. 💡 user-service.ts:55 - Variable name `d` should be `userProfiles`
6. ❓ cache.ts:30 - Why polling instead of webhooks? (asking about design)
7. ✅ error-handler.ts:15 - Great custom error types implementation!

**Post these comments to the PR?** (y/n)
```

**Format for each comment**: `[emoji] [file:line] - [one-line summary]`

**Wait for user response** before Phase 6.

### Phase 6: Post Comments (After Approval)

**CRITICAL**: Use GitHub API to post **inline review comments** (not regular PR comments).

**How to post inline comments properly**:

1. **Create a JSON review payload** with all comments in one request
2. **Use GitHub API** via `gh api repos/{owner}/{repo}/pulls/{number}/reviews`
3. **For suggestion blocks**: Use ````suggestion` (no language specification) so GitHub shows "Apply suggestion" button

**GitHub API Format**:
```bash
# Extract repo owner/name from PR URL or use current repo
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Create review with inline comments using GitHub API
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
  --method POST \
  --field event=COMMENT \
  --field body="$(cat <<'EOF'
## Overall Review Summary

**Strengths**: [positive observations]

**Key Issues to Address**:
- [Summary of critical/important issues from inline comments]

**Future Considerations** (not blockers):
- [Out-of-scope suggestions for future work]

---
*🤖 Generated by OpenCode Assistant*
EOF
)" \
  --raw-field comments='[
    {
      "path": "baas/microservices/nodeproxy/routerstate/selector.go",
      "line": 47,
      "body": "⚠️ **Important - Potential Panic**\n\n**Issue**: Description...\n\n```suggestion\n// Fixed code here\n```\n\n---\n*🤖 Generated by OpenCode Assistant*"
    },
    {
      "path": "baas/microservices/nodeproxy/routerstate/provider_state.go",
      "line": 69,
      "body": "Another comment...\n\n---\n*🤖 Generated by OpenCode Assistant*"
    }
  ]'
```

**IMPORTANT - Suggestion Block Syntax**:
- ✅ CORRECT: `\`\`\`suggestion` (no language after backticks)
- ❌ WRONG: `\`\`\`go suggestion` or `\`\`\`typescript` (won't show "Apply" button)

**For multi-line fixes in suggestion blocks**:
```markdown
```suggestion
// Line 1 of the fix
// Line 2 of the fix
// Line 3 of the fix
```
```

**Step-by-step process**:

1. **Prepare JSON payload** with all inline comments
2. **Build comments array** in JSON format with: `path`, `line`, `body`
3. **Escape special characters** in body (newlines, quotes, backticks)
4. **Post single review** with all comments + summary

**Alternative: Write JSON to temp file** (easier for complex reviews):
```bash
# Create JSON payload file
cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "body": "## Overall Review Summary\n\n...",
  "comments": [
    {
      "path": "file1.go",
      "line": 42,
      "body": "Comment 1 with\n```suggestion\nfixed code\n```\n\n---\n*🤖 Generated by OpenCode Assistant*"
    },
    {
      "path": "file2.go", 
      "line": 108,
      "body": "Comment 2..."
    }
  ]
}
EOF

# Post review from file
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
  --method POST \
  --input /tmp/review.json

# Clean up
rm /tmp/review.json
```

**Parallel posting (for > 10 comments)**:

If you have many comments (> 10), split into multiple review submissions:

```bash
# Batch 1: Comments 1-10
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" --method POST --input batch1.json

# Batch 2: Comments 11-20  
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" --method POST --input batch2.json

# Final: Summary comment only
gh pr review ${pr_number} --comment --body "## Overall Review Summary..."
```

**Key points**:
- ✅ Use `gh api` with GitHub REST API for inline comments
- ✅ Use `"line": NUMBER` for the line number to comment on
- ✅ Use `\`\`\`suggestion` blocks (no language) for one-click fixes
- ✅ Include full file path from repo root in `"path"`
- ✅ Escape JSON special characters in body text
- ❌ Don't use `gh pr comment` (creates regular comments, not inline)
- ❌ Don't use `gh pr review --comment` (no inline support)

**Summary comment structure**:
```markdown
## Overall Review Summary

**Overall assessment**: [2-3 sentences on code quality vs PR purpose]

**PR Purpose**: [From description]

**Strengths**:
- [What's done well - specific praise]

**Review provided**: I've left inline comments on specific lines covering:
- 🚨 [X] Critical issues (security, bugs, race conditions)
- ⚠️ [X] Important improvements (performance, architecture)
- 💡 [X] Suggestions (readability, logging)

**Please review the inline comments** - they contain the specific issues and suggested fixes.

**Future Considerations** (optional - not blockers):
- [Broader refactoring opportunity for future work]
- [Architecture improvement outside current scope]
- [Technical debt to track separately]

*Note: Future Considerations are noted for future improvement and do not block this PR.*

---
*🤖 Generated by OpenCode Assistant*
```

**IMPORTANT**: 
- **Do NOT include** specific issue details in "Next steps" (e.g., "Fix race condition in file.go:42")
- All specific issues are already in inline comments with file:line references
- Summary should just indicate categories and counts
- Let inline comments be the source of truth for what to fix

### Phase 7: Confirmation

```
✅ Review posted successfully!

Posted [X] inline comments to PR #[NUMBER]:
- 🚨 [X] Critical | ⚠️ [X] Important | 💡 [X] Suggestions

View: [URL]
```

## Efficient Workflow Example

**Complete review flow** (typical 5-10 minute review):

```
1. PHASE 1: Single bash command (30 seconds)
   → Fetch PR metadata, diff, files changed

2. PHASE 2: Read PR description (1 minute)
   → Understand: What, Why, Scope, Constraints
   → Note: "Adding router state manager with thread-safe provider selection"

3. PHASE 3: Direct code analysis (3-5 minutes)
   → Read 3-5 most important changed files directly
   → Example: Read manager.go, selector.go, provider_state.go
   → Analyze for: security, bugs, performance, architecture, testing
   → NO Task agents needed - analyze yourself

4. PHASE 4: Identify 5-10 issues (2 minutes)
   → Found:
     - selector.go:47 - Potential panic with zero weight
     - provider_state.go:69 - Lock upgrade issue
     - sliding_window.go:84 - Memory leak from slice pruning
     - request_session.go:8 - Missing thread-safety docs
     - concurrency_test.go:1 - Missing race detector

5. PHASE 5: Present for user approval (show list)
   → "Found 5 comments: 2 critical, 2 important, 1 suggestion"
   → Wait for user confirmation

6. PHASE 6: Post via GitHub API (1 minute)
   → Create JSON payload with all comments
   → Single gh api call to post review
   → Include summary comment

7. PHASE 7: Confirm success
   → "✅ Review posted! 5 inline comments on PR #2951"
```

**Key efficiency points**:
- ✅ **No Task agents for analysis** - analyze code yourself (faster)
- ✅ **Single bash command** for PR data (not multiple)
- ✅ **Single API call** to post all comments (not multiple)
- ✅ **Direct file reads** instead of delegating to agents
- ✅ **Focus on changed code only** (don't review entire codebase)

**When to use Task tool** (rarely):
```
Only if you need to search patterns across many files:

Example: "I need to verify if this error handling pattern is consistent 
with how it's done in 10+ other controllers across the codebase"

→ Task: "Search for error handling patterns in src/controllers/*.ts"
```

**Estimated time**:
- Simple PR (1-2 files): 3-5 minutes
- Medium PR (3-5 files): 5-10 minutes
- Complex PR (10+ files): 10-20 minutes

## Comment Templates

**Every comment MUST end with**: `---\n*🤖 Generated by OpenCode Assistant*`

**Use GitHub's suggestion code blocks** for fixes when possible:
- Use `\`\`\`suggestion` instead of regular code blocks for the fix
- GitHub will show an "Apply suggestion" button
- Makes it easy for authors to accept changes with one click

Use these templates for different issue types:

**Critical Security**:
```markdown
🚨 **Critical - Security Issue**

**Issue**: [e.g., SQL injection vulnerability]

**Why critical**: [Security risk and attack vector]

**Fix**:
\`\`\`suggestion
// Secure version - use parameterized queries
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
\`\`\`

**Learning**: [Security principle - e.g., always use parameterized queries, never interpolate user input]

**References**: [OWASP link, codebase example if available]

---
*🤖 Generated by OpenCode Assistant*
```

**Performance Issue**:
```markdown
⚠️ **Important - Performance Issue**

**Issue**: [e.g., N+1 query problem - creates 101 DB calls for 100 posts]

**Why this matters**: [Explain performance impact with numbers]

**Fix**:
\`\`\`suggestion
// Batch fetch all comments in one query
const postIds = posts.map(p => p.id);
const allComments = await db.query(
  'SELECT * FROM comments WHERE post_id IN (?)',
  [postIds]
);

// Group by post_id in memory
const commentsByPost = groupBy(allComments, 'post_id');
posts.forEach(post => {
  post.comments = commentsByPost[post.id] || [];
});
\`\`\`

**Impact**: [Quantified - "101 queries → 2 queries (50x faster)"]

**Learning**: [Performance principle - avoid queries in loops, use batch operations]

---
*🤖 Generated by OpenCode Assistant*
```

**Architecture/Design**:
```markdown
⚠️ **Important - Architecture**

**Issue**: [e.g., Business logic in controller - violates separation of concerns]

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

**Benefits**: [Testability - can test service independently, Reusability - service logic can be used elsewhere]

**Learning**: [Design principle - Controllers handle HTTP, Services handle business logic]

---
*🤖 Generated by OpenCode Assistant*
```

**Readability**:
```markdown
💡 **Suggestion - Readability**

**Why**: [Brief explanation - e.g., "Descriptive names make code self-documenting and reduce cognitive load"]

**Suggestion**:
\`\`\`suggestion
const activeUserProfiles = data
  .filter(item => item.status === 1)
  .map(item => item.value);
\`\`\`

**Principle**: Code is read 10x more than written - optimize for clarity

---
*🤖 Generated by OpenCode Assistant*
```

**Question/Discussion**:
```markdown
❓ **Question - Design Decision**

I noticed [observation]. Was this because [potential reason]?

\`\`\`typescript
[code in question]
\`\`\`

**Trade-offs**:
- Current approach: [pros/cons]
- Alternative: [pros/cons]

Would love to understand your reasoning - there may be constraints I'm not aware of!

---
*🤖 Generated by OpenCode Assistant*
```

**Praise**:
```markdown
✅ **Great Implementation!**

[Specific praise about what's done well]

\`\`\`typescript
[the good code]
\`\`\`

[Why this is good - what principle it follows, problem solved elegantly] 🎯

---
*🤖 Generated by OpenCode Assistant*
```

## Review Guidelines

### What Makes Great Educational Comments

1. **Explain "Why"**: Don't just say "change this"
   - Bad: "This variable name is wrong"
   - Good: "Rename `data` to `userProfiles` - specific names make code self-documenting and reduce cognitive load"

2. **Provide Context**: Reference standards/patterns
   - "Violates SRP because function both fetches AND formats data"
   - "Codebase follows Repository pattern (see user-repository.ts:10)"

3. **Offer Solutions**: Include code examples
   - Show the better approach
   - Explain trade-offs
   - Make it copy-pasteable

4. **Be Specific**: Comment on exact lines
   - Quote exact problematic code
   - Show exact improved code

5. **Balance with Praise**: 
   - Leave positive comments on good code
   - Use emojis: ✅ 🎯 for praise, 🚨 ⚠️ 💡 for issues

6. **Ask Questions**: Frame as curiosity
   - "Why X instead of Y - to avoid Z?"
   - Assume good reasons exist

### Tone

- **Collaborative**: "We could..." not "You did this wrong"
- **Curious**: "Why this approach?" not "This is wrong"
- **Teaching**: "Here's why..." not "Use this"
- **Respectful**: Assume good intentions
- **Empathetic**: Everyone is learning

## Error Handling

- **No PR found**: Ask user for PR URL
- **Invalid URL**: Show expected format
- **Closed/merged**: Ask if they want to review anyway
- **Insufficient permissions**: Suggest `gh auth login`
- **Empty diff**: Inform no changes to review
- **Rate limits**: Suggest waiting

## Edge Cases

- **Very large PRs (100+ files)**: Focus on critical changes, note limitation
- **Auto-generated code**: Skip (package-lock.json, etc.)
- **Formatting-only**: Quick approval with automation note
- **WIP/Draft**: Lighter review, validate approach
- **Dependency updates**: Focus on changelog, security, breaking changes

## Success Criteria

A successful review:
- ✅ Presents to user for approval BEFORE posting
- ✅ Includes OpenCode watermark on every comment
- ✅ Posts as inline comments on specific lines
- ✅ Provides educational explanations
- ✅ Offers concrete code examples
- ✅ Balances criticism with praise
- ✅ Is actionable - clear next steps
- ✅ Feels like learning from a senior dev

---

**Remember**: Your goal is to make the author a better developer, not just improve this one PR. Every review is a teaching opportunity.

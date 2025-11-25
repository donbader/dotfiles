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
```bash
# Review PR from URL (recommended)
/git:review-pr https://github.com/payfazz/straitsx-blockchain/pull/2944

# Review PR for current branch (auto-detect)
/git:review-pr
```

**Priority**: If you provide a PR URL as `$1`, that URL is used regardless of current branch. Otherwise, auto-detects PR for current branch.

## Review Philosophy

Your review should be:
- **Educational**: Explain WHY something should change, not just WHAT
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact line numbers, files, and code patterns
- **Balanced**: Highlight what's done well AND what needs improvement
- **Actionable**: Provide clear next steps the author can take
- **Focused**: Only comment on code within the PR scope
- **Context-aware**: Understand the PR description to know the author's intent

**Goal**: The PR author should feel they learned something valuable from your review.

## Core Principles

### 1. Stay Within Scope

**Inline Comments** - Only for code changes in this PR:
- Security issues, bugs, breaking changes
- Performance problems in new code
- Architecture violations in changed code
- Missing tests for new functionality
- Readability issues in changed code

**Summary "Future Considerations"** - For broader suggestions:
- Refactoring opportunities outside PR scope
- Architecture improvements for future work
- Technical debt to track separately
- Clearly marked as NOT blockers

**Example**:
```
❌ BAD: "This entire UserService should use dependency injection"
   (UserService not changed - creates scope creep)

✅ GOOD: "The new getUserProfile() queries DB directly. Use the existing 
   UserRepository pattern (see getUserById:42) for consistency"
   (getUserProfile() is new - directly relevant)

✅ SUMMARY: "Future: UserService could benefit from dependency injection 
   to improve testability (not a blocker for this OAuth PR)"
```

### 2. Read PR Description for Context

Always analyze the PR description to understand:
- **What**: Author's stated goal
- **Why**: Motivation for changes
- **Scope**: Hotfix, feature, refactor, or bug fix
- **Constraints**: Known trade-offs or limitations
- **Testing**: Author's testing approach

This prevents commenting on intentional decisions or asking already-answered questions.

## Workflow (6 Phases)

### Phase 1: Fetch PR Information

**Single bash command** to fetch everything:

```bash
# Extract PR number from URL ($1) or current branch
if [ -n "$1" ]; then
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  echo "=== INFO: Using PR from provided URL ==="
else
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
fi

if [ -z "$pr_number" ]; then 
  echo "ERROR: No PR found. Provide a PR URL or ensure current branch has a PR."
  exit 1
fi

echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- PR URL from `$1` takes priority over current branch
- Single chained command for efficiency
- Capture PR description (critical for context)

### Phase 2: Understand PR Context

**Before analyzing code**, read the PR description to extract:
1. **Purpose**: What is the author trying to achieve?
2. **Scope**: Bug fix, feature, refactor, hotfix?
3. **Constraints**: Trade-offs or technical debt mentioned?
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

### Phase 3: Analyze Code

**IMPORTANT**: Analyze code directly yourself. Do NOT use Task tool unless searching patterns across many files.

**Steps**:
1. **Read the PR diff** to identify changed files and line ranges
2. **Read 3-5 most important changed files** for full context
3. **Analyze changes** for issues (see categories below)

**Analysis categories** (priority order):

1. **Security & Bugs** 🚨
   - Security vulnerabilities (SQL injection, XSS, auth bypasses)
   - Logic errors, null handling issues
   - Race conditions, deadlocks, resource leaks
   - Breaking changes to public APIs

2. **Performance** ⚠️
   - N+1 query problems
   - Inefficient algorithms (O(n²) when O(n) exists)
   - Memory leaks, unnecessary allocations

3. **Architecture & Design** ⚠️
   - Violations of established patterns
   - Separation of concerns issues
   - Inconsistent error handling

4. **Testing** 💡
   - New functionality without tests
   - Missing edge case coverage

5. **Readability** 💡
   - Confusing variable names or logic
   - Missing documentation for public APIs

**Why direct analysis is better**:
- ✅ Faster (no Task overhead)
- ✅ Better context (you have the diff)
- ❌ Task agents add latency

**When to use Task tool** (rarely):
Only if you need to search patterns across many files to validate a concern.

Example: "Search for error handling patterns in src/controllers/*.ts to verify consistency"

### Phase 4: Identify Issues

**Aim for 3-10 meaningful comments**, not 50+ nitpicks.

**Apply scope filters**:
- Is this in the diff?
- Within PR's stated purpose?
- Already addressed in description?
- Pre-existing issue unrelated to changes?

**Guidelines**:
- **Security & Bugs**: Always comment if found
- **Performance**: Only if significant impact (quantify)
- **Architecture**: Only if violates established patterns
- **Testing**: If new functionality lacks tests
- **Readability**: Only truly confusing code
- **Future Improvements**: Save for summary's "Future Considerations"

### Phase 5: Present for Approval

**CRITICAL**: Present to user for approval BEFORE posting.

**Display format**:
```
## Review Summary for PR #[NUMBER]: [Title]

**Found [X] comments**:
- 🚨 [X] Critical (security, bugs)
- ⚠️ [X] Important (performance, architecture)
- 💡 [X] Suggestions (readability, best practices)

**Comments to post**:

1. 🚨 auth.ts:42 - SQL injection vulnerability in login query
2. ⚠️ user-controller.ts:85 - N+1 query problem when fetching user posts
3. 💡 user-service.ts:55 - Variable name `d` should be `userProfiles`

**Post these comments to the PR?** (y/n)
```

**Wait for user response** before Phase 6.

### Phase 6: Post Comments

**CRITICAL RULES**:
- ✅ Post ALL comments + summary in ONE review via GitHub API
- ✅ Every review MUST include at least one inline comment
- ❌ NEVER post summary-only reviews (they can't be deleted via API)
- ❌ NEVER use `gh pr review --comment` separately

**Correct approach** (write JSON to temp file):

```bash
# Get repo info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Create review JSON with ALL comments + summary
cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "body": "## Overall Review Summary\n\n**Overall assessment**: [2-3 sentences]\n\n**Strengths**:\n- [Specific praise]\n\n**Review provided**: I've left inline comments covering:\n- 🚨 [X] Critical issues\n- ⚠️ [X] Important improvements\n- 💡 [X] Suggestions\n\n**Future Considerations** (not blockers):\n- [Out-of-scope suggestions]\n\n---\n*🤖 Generated by OpenCode Assistant*",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 42,
      "body": "🚨 **Critical - Security Issue**\n\n**Issue**: SQL injection vulnerability\n\n**Fix**:\n```suggestion\nconst query = 'SELECT * FROM users WHERE id = ?';\nconst result = await db.query(query, [userId]);\n```\n\n**Learning**: Always use parameterized queries\n\n---\n*🤖 Generated by OpenCode Assistant*"
    },
    {
      "path": "src/user-controller.ts",
      "line": 85,
      "body": "⚠️ **Important - Performance**\n\n**Issue**: N+1 query problem\n\n**Fix**:\n```suggestion\nconst postIds = posts.map(p => p.id);\nconst allComments = await db.query(\n  'SELECT * FROM comments WHERE post_id IN (?)',\n  [postIds]\n);\n```\n\n**Impact**: 101 queries → 2 queries (50x faster)\n\n---\n*🤖 Generated by OpenCode Assistant*"
    }
  ]
}
EOF

# Post review
gh api "repos/${repo_info}/pulls/${pr_number}/reviews" \
  --method POST \
  --input /tmp/review.json

# Clean up
rm /tmp/review.json
```

**Suggestion block syntax**:
- ✅ CORRECT: `\`\`\`suggestion` (no language)
- ❌ WRONG: `\`\`\`go` or `\`\`\`typescript` (won't show "Apply" button)

**For large reviews (> 10 comments)**:
Split into batches, but put full summary in LAST batch:
```bash
# Batch 1: Comments 1-10
{"event": "COMMENT", "body": "Review batch 1/2", "comments": [...]}

# Batch 2: Comments 11-20 + full summary
{"event": "COMMENT", "body": "## Overall Review Summary...", "comments": [...]}
```

### Phase 7: Confirmation

```
✅ Review posted successfully!

Posted [X] inline comments to PR #[NUMBER]:
- 🚨 [X] Critical | ⚠️ [X] Important | 💡 [X] Suggestions

View: [URL]
```

## Comment Templates

**Every comment MUST end with**: `---\n*🤖 Generated by OpenCode Assistant*`

### Critical Security

```markdown
🚨 **Critical - Security Issue**

**Issue**: [e.g., SQL injection vulnerability]

**Why critical**: [Security risk and attack vector]

**Fix**:
\`\`\`suggestion
// Secure version
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
\`\`\`

**Learning**: [Security principle]

**References**: [OWASP link, codebase example if available]

---
*🤖 Generated by OpenCode Assistant*
```

### Performance Issue

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
\`\`\`

**Impact**: [Quantified - "101 queries → 2 queries (50x faster)"]

**Learning**: [Performance principle]

---
*🤖 Generated by OpenCode Assistant*
```

### Architecture/Design

```markdown
⚠️ **Important - Architecture**

**Issue**: [e.g., Business logic in controller]

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
*🤖 Generated by OpenCode Assistant*
```

### Readability

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
*🤖 Generated by OpenCode Assistant*
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
*🤖 Generated by OpenCode Assistant*
```

### Praise

```markdown
✅ **Great Implementation!**

[Specific praise about what's done well]

\`\`\`typescript
[the good code]
\`\`\`

[Why this is good - principle followed, problem solved elegantly] 🎯

---
*🤖 Generated by OpenCode Assistant*
```

## Review Guidelines

### What Makes Great Educational Comments

1. **Explain "Why"**: Don't just say "change this"
   - Bad: "This variable name is wrong"
   - Good: "Rename `data` to `userProfiles` - specific names make code self-documenting"

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

## Common Mistakes to Avoid

### ❌ CRITICAL: Don't Post Summary-Only Reviews

**Problem**: Summary-only reviews (without inline comments) CANNOT be deleted via API.

**Wrong**:
```bash
# DON'T DO THIS - creates non-deletable review
gh pr review ${pr_number} --comment --body "## Overall Review Summary..."
```

**Correct**:
```bash
# Post everything in ONE review with inline comments
{
  "event": "COMMENT",
  "body": "## Overall Review Summary...",
  "comments": [
    {"path": "file.go", "line": 42, "body": "Comment 1..."},
    {"path": "file.go", "line": 108, "body": "Comment 2..."}
  ]
}
```

**Key rule**: Every review MUST include at least one inline comment.

## Error Handling

- **No PR found**: Ask user for PR URL
- **Invalid URL**: Show expected format
- **Closed/merged**: Ask if they want to review anyway
- **Insufficient permissions**: Suggest `gh auth login`
- **Empty diff**: Inform no changes to review

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

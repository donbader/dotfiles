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
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

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
  # Get PR branch name
  pr_branch=$(gh pr view $pr_number --json headRefName -q .headRefName)
  
  # Create unique worktree directory
  worktree_dir="/tmp/pr-review-${pr_number}-$$"
  
  # Fetch PR branch and create worktree
  git fetch origin "$pr_branch:$pr_branch" 2>/dev/null || git fetch origin "$pr_branch"
  git worktree add "$worktree_dir" "$pr_branch"
  
  # Change to worktree directory
  cd "$worktree_dir"
  
  echo "=== Created worktree at $worktree_dir ==="
fi
```

### Phase 2: Fetch PR Information

**Single bash command** to fetch all required data:

```bash
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- Worktree created if reviewing PR from URL
- Single chained command for efficiency
- Captures PR description for context

### Phase 3: Analyze PR Context

**Before reviewing code**, extract context from PR description:
1. **Purpose**: What is the author trying to achieve?
2. **Scope**: Bug fix, feature, refactor, hotfix?
3. **Constraints**: Any trade-offs or technical debt mentioned?
4. **Testing**: What testing approach was taken?

### Phase 4: Analyze Code

**IMPORTANT**: Analyze code directly. Do NOT use Task tool unless searching patterns across many files.

**Analysis steps**:
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

### Phase 5: Identify Issues

**Aim for 3-10 meaningful comments**, not 50+ nitpicks.

**Scope filters** (ask yourself):
- Is this code in the diff?
- Within PR's stated purpose?
- Already addressed in PR description?
- Pre-existing issue unrelated to these changes?

**Comment guidelines by category**:
- **Security & Bugs** 🚨: Always comment
- **Performance** ⚠️: Only if significant impact (quantify when possible)
- **Architecture** ⚠️: Only if violates established patterns
- **Testing** 💡: If new functionality lacks tests
- **Readability** 💡: Only truly confusing code
- **Future Improvements**: Save for summary section

### Phase 6: Present for User Approval

**CRITICAL**: Present review to user for approval BEFORE posting.

**Display format**:
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

**Wait for user confirmation** before proceeding to Phase 7.

### Phase 7: Post Review

**CRITICAL RULES**:
- ✅ Post ALL comments + summary in ONE review via GitHub API
- ✅ Every review MUST include at least one inline comment
- ❌ NEVER post summary-only reviews (cannot be deleted via API)
- ❌ NEVER use `gh pr review --comment` separately

**Correct approach** (JSON to temp file):

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

**Key notes**:
- Suggestion blocks: Use `\`\`\`suggestion` (no language specifier for "Apply" button)
- Large reviews (>10 comments): Split into batches, full summary in LAST batch only
- Every comment MUST end with: `---\n*🤖 Generated by OpenCode*`
- Use `-F field=@file` or `-f field=value` instead of embedding in JSON to avoid escaping issues
- Test API endpoints work before relying on them in automation

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

Display confirmation message:

```
✅ Review posted successfully!

Posted [X] inline comments to PR #[NUMBER]:
- 🚨 [X] Critical | ⚠️ [X] Important | 💡 [X] Suggestions

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

**Key rule**: Every review MUST include at least one inline comment.

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
  - Ensure `/tmp` directory is writable
  - Clean up any existing worktree at that path
- **Worktree cleanup fails**: Force remove and warn user about manual cleanup if needed

## Edge Cases

Special PR scenarios to handle:

- **Large PRs (100+ files)**: Focus on critical changes, note scope limitation in summary
- **Auto-generated code**: Skip files like package-lock.json, generated protobuf, etc.
- **Formatting-only changes**: Quick approval with note about automation
- **WIP/Draft PRs**: Lighter review focusing on approach validation
- **Dependency updates**: Focus on changelog, security advisories, breaking changes

## Success Criteria

A successful review meets these requirements:

- ✅ Presents review to user for approval BEFORE posting
- ✅ Includes OpenCode watermark on every comment and summary
- ✅ Posts as inline comments on specific lines with context
- ✅ Provides educational explanations with "why" not just "what"
- ✅ Offers concrete, actionable code examples
- ✅ Balances constructive criticism with genuine praise
- ✅ Gives clear, implementable next steps
- ✅ Feels like learning from an experienced developer

---

**Remember**: Every review is a teaching opportunity. The goal is to help developers grow their skills, not just improve one PR.

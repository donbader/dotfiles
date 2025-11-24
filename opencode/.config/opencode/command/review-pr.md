---
name: git:review-pr
description: Provide comprehensive, educational code review for a GitHub PR
---

# Review GitHub Pull Request

Perform a thorough, educational code review of a GitHub PR with constructive feedback that helps the author learn and improve their code quality.

## Usage

The command accepts PR specification in two ways:
1. **Explicit PR URL**: User provides the full GitHub PR URL
2. **Current Branch PR**: Auto-detect PR for the current branch using `gh pr view`

## Review Philosophy

Your review should be:
- **Educational**: Explain WHY something should change, not just WHAT to change
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact line numbers, files, and code patterns
- **Balanced**: Highlight what's done well AND what needs improvement
- **Actionable**: Provide clear next steps the author can take

**Goal**: The PR author should feel they learned something valuable from your review, whether the PR is approved or needs changes.

## Workflow

### Phase 1: Fetch PR Information (Single Bash Call)

Execute ALL of these commands in parallel in a **single Bash tool call** using command grouping:

```bash
# If user provided PR URL, extract PR number and set as variable
# Otherwise use current branch PR
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
pr_number=${PR_NUMBER:-$(gh pr view --json number -q .number 2>/dev/null)}; \
if [ -z "$pr_number" ]; then echo "ERROR: No PR found"; exit 1; fi; \
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== CURRENT_BRANCH ===" && echo "$current_branch" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,headRefName,baseRefName,createdAt,commits,additions,deletions,changedFiles,url && \
echo "=== COMMIT_HISTORY ===" && gh pr view $pr_number --json commits -q '.commits[].commit | "\(.messageHeadline)\n\(.message)\n---"' && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points:**
- Use command grouping with `;` and `&&` to chain commands
- Use `echo "=== SECTION ===" ` markers to parse output easily
- Extract PR number from URL if provided (format: `https://github.com/owner/repo/pull/123`)
- Fetch all metadata in one go to minimize API calls
- Capture full diff for detailed code analysis

### Phase 2: Parallel Code Analysis (Multi-Tool Calls)

Once you have the PR diff and metadata, perform these analyses **in parallel** using multiple tool calls in a single response:

1. **Read changed files** (if they exist locally) using Read tool
   - Identify the 5-10 most critical files from the diff
   - Read full file context to understand surrounding code
   - Look for patterns, architecture, and design decisions

2. **Search for related code** using Grep/Glob tools
   - Find similar patterns in the codebase (if suggesting changes)
   - Look for existing tests related to changed code
   - Identify if there are established conventions being violated

3. **Check for documentation** using Glob tool
   - Look for README files in affected directories
   - Check if there's a CONTRIBUTING guide
   - Find architecture documentation if available

**IMPORTANT**: Execute all independent searches/reads in parallel within a single assistant message using multiple tool invocations.

### Phase 3: Comprehensive Analysis

Analyze the PR across these dimensions:

#### 1. Code Quality
- **Readability**: Is the code easy to understand? Are names descriptive?
- **Complexity**: Are functions too long? Is logic nested too deeply?
- **Patterns**: Does it follow established patterns in the codebase?
- **DRY principle**: Is there code duplication?
- **Error handling**: Are edge cases and errors handled properly?

#### 2. Architecture & Design
- **Separation of concerns**: Are responsibilities well-divided?
- **SOLID principles**: Single responsibility, open/closed, etc.
- **Coupling**: Are components too tightly coupled?
- **Abstraction**: Is the right level of abstraction used?
- **Scalability**: Will this work at scale?

#### 3. Testing
- **Coverage**: Are there tests for new functionality?
- **Test quality**: Do tests cover edge cases and error scenarios?
- **Test clarity**: Are test names descriptive? Is intent clear?
- **Mocking**: Are external dependencies properly mocked?

#### 4. Security
- **Input validation**: Are user inputs validated/sanitized?
- **Authentication/Authorization**: Are permissions checked?
- **Data exposure**: Could sensitive data leak?
- **Injection vulnerabilities**: SQL, XSS, command injection risks?
- **Dependency security**: Are new dependencies safe?

#### 5. Performance
- **Algorithmic complexity**: Is the Big O reasonable?
- **Database queries**: N+1 queries? Proper indexing?
- **Memory usage**: Potential memory leaks?
- **Caching**: Could caching improve performance?
- **Unnecessary work**: Redundant calculations or fetches?

#### 6. Documentation
- **Code comments**: Complex logic explained?
- **API documentation**: Public APIs documented?
- **README updates**: New features documented?
- **Changelog**: Should this be noted in CHANGELOG?

### Phase 4: Parse Diff and Identify Review Points

Parse the diff output to extract:
- Changed files with their line ranges
- Added/modified code sections
- Deleted code sections

For each significant change, determine:
- **Severity**: Critical (must fix), Important (should fix), Suggestion (nice to have)
- **Category**: Security, Bug, Performance, Architecture, Readability, Testing, Documentation
- **File path and exact line numbers** where the issue occurs

**IMPORTANT**: Only review actual code changes visible in the diff. Don't make assumptions about code outside the diff unless you've read the full file context.

### Phase 5: Present Review to User for Approval

**CRITICAL**: Do NOT post comments automatically. Present the full review to the user first.

**Display to user**:
1. **Summary** of what you found:
   - Total number of comments by category (Critical/Important/Suggestions/Questions/Praise)
   - List of files that will receive comments
   - Overall assessment

2. **All inline comments** formatted clearly:
   ```
   📁 path/to/file.ts:42
   🚨 **Critical - Security Issue**
   [full comment text]
   
   📁 path/to/file.ts:108
   ⚠️ **Important - Performance Issue**
   [full comment text]
   
   ...
   ```

3. **Ask for approval**:
   ```
   Ready to post this review to the PR?
   - Type 'yes' or 'y' to post all comments
   - Type 'no' or 'n' to cancel
   - Suggest specific edits if you want me to modify any comments first
   ```

**Wait for user response** before proceeding to Phase 6.

### Phase 6: Post Inline Comments (After User Approval)

Only execute this phase after user explicitly approves.

Post inline comments directly on the specific lines of code using `gh pr review`. This is the PRIMARY review method.

**Strategy**: Batch ALL inline comments into a single Bash command for efficiency.

```bash
gh pr review <PR_NUMBER> --comment \
  --body "$(cat <<'EOF'
## Overall Review Summary

**Status**: Ready for detailed inline feedback - please review my comments below

**Overall assessment**: [2-3 sentences on general code quality, approach, and what stands out]

**Strengths**:
- [What's done well - be general here, specifics go in inline comments]
- [Good architectural decisions]

**Focus areas**: I've left inline comments on specific lines covering:
- [Number] critical issues (security, bugs)
- [Number] important improvements (performance, architecture)
- [Number] suggestions (readability, best practices)

**Next steps after addressing comments**:
1. [Most critical action]
2. [Second priority]

Please check the inline comments on specific files and lines for detailed feedback!

---
*🤖 Generated by OpenCode Assistant*
EOF
)" \
  $(echo "$INLINE_COMMENTS")
```

Where `$INLINE_COMMENTS` is constructed from individual review comments:

```bash
# Build inline comments (example structure - construct this programmatically)
INLINE_COMMENTS=""

# Critical issue example
INLINE_COMMENTS+=" --comment-file path/to/file.ts --comment-line 42 --comment-body \"$(cat <<'COMMENT'
🚨 **Critical - Security Issue**

**Issue**: SQL injection vulnerability

\`\`\`typescript
// Current code (vulnerable)
const query = \`SELECT * FROM users WHERE id = \${userId}\`;
\`\`\`

**Why this is critical**: Direct string interpolation of user input allows attackers to inject malicious SQL. An attacker could pass \`1 OR 1=1\` to access all user records, or \`1; DROP TABLE users\` to destroy data.

**Fix**:
\`\`\`typescript
// Use parameterized queries
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
\`\`\`

**Learning point**: Always treat user input as untrusted. Parameterized queries separate code from data, making SQL injection impossible. The database driver properly escapes parameters.

**References**: 
- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- See \`user-repository.ts:15\` for our established pattern
COMMENT
)\""

# Important improvement example
INLINE_COMMENTS+=" --comment-file path/to/file.ts --comment-line 108 --comment-body \"$(cat <<'COMMENT'
⚠️ **Important - Performance Issue**

**Issue**: N+1 query problem

\`\`\`typescript
// Current code (inefficient)
for (const post of posts) {
  post.comments = await db.query('SELECT * FROM comments WHERE post_id = ?', [post.id]);
}
\`\`\`

**Why this matters**: This creates 1 query for posts + N queries for comments. With 100 posts, that's 101 database roundtrips instead of 2. At scale, this causes severe performance degradation.

**Fix**:
\`\`\`typescript
// Batch fetch all comments
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

**Impact**: Reduces 101 queries → 2 queries (50x faster). Critical for scalability.

**Learning point**: Watch for queries inside loops. Always consider batch fetching or eager loading for related data. The database is optimized for set operations, not iterative fetches.
COMMENT
)\""

# Suggestion example  
INLINE_COMMENTS+=" --comment-file path/to/file.ts --comment-line 200 --comment-body \"$(cat <<'COMMENT'
💡 **Suggestion - Readability**

**Current**:
\`\`\`typescript
const d = data.filter(x => x.s === 1).map(x => x.v);
\`\`\`

**Suggestion**:
\`\`\`typescript
const activeValues = data
  .filter(item => item.status === 1)
  .map(item => item.value);
\`\`\`

**Why**: Descriptive names make code self-documenting. Future maintainers (including yourself in 6 months) will immediately understand what \`activeValues\` represents without mental parsing.

**Principle**: Code is read 10x more than it's written. Optimize for readability over brevity.
COMMENT
)\""

# Question/Discussion example
INLINE_COMMENTS+=" --comment-file path/to/file.ts --comment-line 75 --comment-body \"$(cat <<'COMMENT'
❓ **Question - Design Decision**

I noticed you're using a polling mechanism here instead of webhooks. Was this to handle cases where webhook delivery fails?

\`\`\`typescript
setInterval(() => checkForUpdates(), 5000);
\`\`\`

**Trade-offs I'm considering**:
- **Polling**: Simpler, more reliable, but less efficient and has 5s delay
- **Webhooks**: Real-time, efficient, but requires handling failures and retries

**Alternative approach** (if webhooks are viable):
\`\`\`typescript
// Webhook endpoint + fallback polling
app.post('/webhook/updates', handleUpdate);

// Fallback polling only for missed events
setInterval(() => checkMissedUpdates(), 60000); // 1 min
\`\`\`

Would love to understand your reasoning here - there may be constraints I'm not aware of!
COMMENT
)\""

# Praise example (yes, praise specific good code!)
INLINE_COMMENTS+=" --comment-file path/to/file.ts --comment-line 150 --comment-body \"$(cat <<'COMMENT'
✅ **Great Implementation!**

Love this error handling approach! The custom error types make it easy to handle different failure scenarios, and the error messages are clear and actionable.

\`\`\`typescript
if (!user) {
  throw new NotFoundError(\`User with id \${userId} not found\`);
}

if (!user.isActive) {
  throw new ForbiddenError('User account is deactivated');
}
\`\`\`

This makes debugging much easier and provides great UX when errors surface to the client. Well done! 🎯

---
*🤖 Generated by OpenCode Assistant*
COMMENT
)\""
```

**Note**: The actual implementation should construct these inline comments programmatically based on your analysis in Phase 3-4. Use Bash to build the command with all inline comments. Remember to add the OpenCode watermark to every comment.

### Phase 5b: Alternative - Use gh API for Inline Comments

For better control and parallelization, use the GitHub API directly:

```bash
# Post multiple inline comments in parallel (single Bash call with multiple API requests)
pr_number=<PR_NUMBER>
commit_sha=$(gh pr view $pr_number --json headRefOid -q .headRefOid)

# Comment 1
curl -X POST \
  -H "Authorization: token $(gh auth token)" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/<OWNER>/<REPO>/pulls/$pr_number/comments" \
  -d @- <<'EOF' &
{
  "body": "🚨 **Critical**: [Your detailed comment here]\n\n---\n*🤖 Generated by OpenCode Assistant*",
  "commit_id": "'"$commit_sha"'",
  "path": "path/to/file.ts",
  "line": 42
}
EOF

# Comment 2  
curl -X POST ... &

# Comment 3
curl -X POST ... &

# Wait for all comments to post
wait

# Then post overall review
gh pr review $pr_number --comment --body "$(cat <<'EOF'
## Overall Review Summary

**Status**: Detailed inline feedback posted

**Overall assessment**: [2-3 sentences]

**Focus areas**: I've left inline comments on specific lines covering:
- 🚨 [X] Critical issues
- ⚠️ [X] Important improvements
- 💡 [X] Suggestions

**Next steps**: Please review the inline comments on specific files and lines!

---
*🤖 Generated by OpenCode Assistant*
EOF
)"
```

This allows posting all inline comments in parallel (faster for many comments).

**Remember**: Every comment body must end with the OpenCode watermark.

### Phase 7: Confirmation

After successfully posting all comments, confirm to the user:

```
✅ Review posted successfully!

Posted [X] inline comments to PR #[NUMBER]:
- 🚨 [X] Critical issues
- ⚠️ [X] Important improvements  
- 💡 [X] Suggestions
- ❓ [X] Questions
- ✅ [X] Praise

View the PR: [URL]
```

## Review Guidelines

### What Makes a Great Educational Inline Comment

1. **Explain the "Why"**: Don't just say "change this" - explain why it matters
   - Bad: "This variable name is wrong"
   - Good: "Consider renaming `data` to `userProfiles` - specific names make the code self-documenting and help future maintainers understand the data structure at a glance. This reduces cognitive load when debugging."

2. **Provide Context**: Reference standards, patterns, or principles
   - "This violates the Single Responsibility Principle because this function both fetches data AND formats it. Consider separating these concerns."
   - "Our codebase follows the Repository pattern (see `user-repository.ts:10`), so data access should go through a repository class rather than direct DB calls here."

3. **Offer Solutions**: Don't just identify problems
   - Always include code examples showing the better approach
   - Explain trade-offs when multiple solutions exist
   - Make it copy-pasteable when possible

4. **Be Specific**: Comment on exact lines
   - The inline comment is already on the specific line - great!
   - Quote the exact problematic code in the comment
   - Show the exact improved code

5. **Balance Criticism with Praise**
   - Leave positive inline comments on good implementations
   - Use encouraging emojis (✅ 🎯) for praise
   - Use warning emojis (🚨 ⚠️ 💡) for issues

6. **Prioritize Issues**: Use visual indicators
   - 🚨 Critical: Security issues, bugs, breaking changes
   - ⚠️ Important: Performance problems, poor architecture  
   - 💡 Suggestion: Naming, minor refactoring
   - ❓ Question: Clarification needed
   - ✅ Praise: Great implementation

7. **Ask Questions**: Sometimes the author had good reasons
   - "I noticed you used X instead of Y - was this to avoid Z issue?"
   - "Can you help me understand why you chose this approach over [alternative]?"
   - Frame as curiosity, not criticism

### Tone Guidelines

- **Collaborative**: "We could improve this by..." vs "You did this wrong"
- **Curious**: "Why did you choose this approach?" vs "This approach is wrong"
- **Teaching**: "Here's why this pattern is better..." vs "Use this pattern"
- **Respectful**: Assume good intentions and skill
- **Empathetic**: Remember everyone is learning

### Inline Comment Templates

**IMPORTANT**: Every inline comment MUST end with the OpenCode watermark:
```
---
*🤖 Generated by OpenCode Assistant*
```

Use these templates for different issue types:

**Critical Security Issue**:
```markdown
🚨 **Critical - Security Issue**

**Issue**: [What's wrong - e.g., SQL injection vulnerability]

\`\`\`typescript
// Current code (vulnerable)
[exact problematic code]
\`\`\`

**Why this is critical**: [Explain the security risk and potential attack vector]

**Fix**:
\`\`\`typescript
// Secure version
[exact improved code]
\`\`\`

**Learning point**: [Explain the security principle - e.g., input validation, parameterized queries, etc.]

**References**: 
- [OWASP link or internal docs]
- [Example in codebase: file.ts:line]

---
*🤖 Generated by OpenCode Assistant*
```

**Performance Issue**:
```markdown
⚠️ **Important - Performance Issue**

**Issue**: [What's wrong - e.g., N+1 query problem]

\`\`\`typescript
// Current code (inefficient)
[exact problematic code]
\`\`\`

**Why this matters**: [Explain performance impact with numbers if possible]

**Fix**:
\`\`\`typescript
// Optimized version
[exact improved code]
\`\`\`

**Impact**: [Quantify improvement - e.g., "101 queries → 2 queries (50x faster)"]

**Learning point**: [Explain the performance principle - e.g., batch operations, caching, etc.]

---
*🤖 Generated by OpenCode Assistant*
```

**Architecture/Design Issue**:
```markdown
⚠️ **Important - Architecture**

**Issue**: [What's wrong - e.g., Business logic in controller]

\`\`\`typescript
// Current code (couples concerns)
[exact problematic code]
\`\`\`

**Why this matters**: [Explain maintainability/testability impact]

**Fix**:
\`\`\`typescript
// Separated concerns
[exact improved code]
\`\`\`

**Benefits**: [List specific benefits - testability, reusability, clarity]

**Learning point**: [Explain the design principle - e.g., SRP, dependency injection, etc.]

---
*🤖 Generated by OpenCode Assistant*
```

**Readability Suggestion**:
```markdown
💡 **Suggestion - Readability**

**Current**:
\`\`\`typescript
[current code]
\`\`\`

**Suggestion**:
\`\`\`typescript
[improved code]
\`\`\`

**Why**: [Brief explanation - e.g., "Descriptive names make code self-documenting"]

**Principle**: [e.g., "Code is read 10x more than written - optimize for readability"]

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

**Trade-offs I'm considering**:
- **Current approach**: [pros and cons]
- **Alternative approach**: [pros and cons]

**Alternative** (if it helps):
\`\`\`typescript
[alternative implementation]
\`\`\`

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

[Why this is good - what principle it follows, what problem it solves elegantly]

[Optional: What others can learn from this] 🎯

---
*🤖 Generated by OpenCode Assistant*
```

## Error Handling

- **No PR found for current branch**: Ask user to provide PR URL explicitly
- **Invalid PR URL format**: Show expected format and ask again
- **PR is closed/merged**: Inform user and ask if they want to review anyway
- **Insufficient permissions**: User may need to authenticate with `gh auth login`
- **Empty PR diff**: Inform user there are no changes to review
- **API rate limits**: Suggest waiting or using cached data if available

## Efficiency Notes

- **Batch all git/gh commands** in Phase 1 into single Bash call
- **Parallel tool usage** in Phase 2 - call Read, Grep, Glob simultaneously  
- **Batch inline comments** in Phase 5 - construct all comments and post in one command
- **Consider API for many comments**: For 10+ comments, use GitHub API with parallel curl requests
- **Cache PR data**: If reviewing same PR multiple times, reuse fetched data
- **Limit file reads**: Only read most critical/changed files (5-10 max)
- **Focus on changed lines**: Only review code in the diff, unless broader context is needed

## Implementation Strategy

### How to Post Multiple Inline Comments Efficiently

Since `gh pr review` doesn't directly support multiple inline comments in one call, use this approach:

**Option 1: Multiple review comments (simpler but slower)**
```bash
# Post each inline comment separately (in a single Bash call)
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 42; \
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 108; \
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 200; \
gh pr review <PR_NUMBER> --comment --body "Overall summary..."
```

**Option 2: GitHub API with parallel requests (faster for many comments)**
```bash
pr_number=<PR_NUMBER>
commit_sha=$(gh pr view $pr_number --json headRefOid -q .headRefOid)
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
token=$(gh auth token)

# Function to post comment
post_comment() {
  local file=$1
  local line=$2  
  local body=$3
  
  curl -s -X POST \
    -H "Authorization: token $token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$repo/pulls/$pr_number/comments" \
    -d "$(jq -n \
      --arg body "$body" \
      --arg commit "$commit_sha" \
      --arg path "$file" \
      --arg line "$line" \
      '{body: $body, commit_id: $commit, path: $path, line: ($line | tonumber)}'
    )" > /dev/null &
}

# Post all comments in parallel (each comment should already include the watermark)
post_comment "path/to/file.ts" "42" "🚨 **Critical**: ...\n\n---\n*🤖 Generated by OpenCode Assistant*"
post_comment "path/to/file.ts" "108" "⚠️ **Important**: ...\n\n---\n*🤖 Generated by OpenCode Assistant*"
post_comment "path/to/file.ts" "200" "💡 **Suggestion**: ...\n\n---\n*🤖 Generated by OpenCode Assistant*"

# Wait for all to complete
wait

# Post overall review
gh pr review $pr_number --comment --body "$(cat <<'EOF'
## Overall Review Summary

**Status**: Detailed inline feedback posted

**Overall assessment**: [2-3 sentences]

**Focus areas**: I've left inline comments covering:
- 🚨 [X] Critical issues
- ⚠️ [X] Important improvements
- 💡 [X] Suggestions

**Next steps**: Please review the inline comments!

---
*🤖 Generated by OpenCode Assistant*
EOF
)"
```

**Recommended**: Use Option 1 for < 10 comments, Option 2 for 10+ comments.

**CRITICAL**: Every comment body must include the OpenCode watermark at the end.

## Edge Cases

- **Very large PRs (100+ files)**: Focus on most critical changes, note scope limitation
- **Auto-generated code**: Skip reviewing generated files (package-lock.json, etc.)
- **Formatting-only changes**: Quick approval with note about automation
- **WIP/Draft PRs**: Lighter review, focus on approach validation
- **Dependency updates**: Focus on changelog, security advisories, breaking changes

## Success Criteria

A successful review should:
- ✅ Present all comments to user for approval BEFORE posting
- ✅ Include OpenCode watermark on every comment
- ✅ Be posted as inline comments on specific lines (not just a summary)
- ✅ Include specific file:line references for all issues
- ✅ Provide educational explanations for all feedback
- ✅ Offer concrete code examples for improvements
- ✅ Balance criticism with recognition of good work
- ✅ Be actionable - author knows exactly what to do next
- ✅ Feel like learning from a senior developer, not being scolded

## Example Commands

```bash
# Review PR from current branch
/review-pr

# Review specific PR by URL
/review-pr https://github.com/owner/repo/pull/123

# Review with different approval status
/review-pr --status approve
/review-pr --status request-changes
/review-pr --status comment
```

---

**Remember**: Your goal is to make the author a better developer, not just improve this one PR. Every review is a teaching opportunity.

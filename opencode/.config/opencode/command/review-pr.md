---
name: git:review-pr
description: Provide comprehensive, educational code review for a GitHub PR
---

# Review GitHub Pull Request

Perform a thorough, educational code review of a GitHub PR with constructive feedback that helps the author learn and improve their code quality.

## Usage

Accept PR in two ways:
1. **Explicit PR URL**: User provides the full GitHub PR URL
2. **Current Branch PR**: Auto-detect PR for current branch using `gh pr view`

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
Structure your review process in independent phases:
- **Data Gathering**: Fetch PR information (metadata, diff, description)
- **Context Analysis**: Understand PR intent from description and commits
- **Code Analysis**: Examine changed code only
- **Comment Generation**: Create focused, educational feedback
- **User Approval**: Present for review before posting
- **Comment Posting**: Execute approved comments

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

```bash
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
pr_number=${PR_NUMBER:-$(gh pr view --json number -q .number 2>/dev/null)}; \
if [ -z "$pr_number" ]; then echo "ERROR: No PR found"; exit 1; fi; \
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,headRefName,baseRefName,url && \
echo "=== COMMIT_HISTORY ===" && gh pr view $pr_number --json commits -q '.commits[].commit | "\(.messageHeadline)\n---"' && \
echo "=== FILES_CHANGED ===" && gh pr view $pr_number --json files -q '.files[] | "\(.path) (+\(.additions)/-\(.deletions))"' && \
echo "=== PR_DIFF ===" && gh pr diff $pr_number
```

**Key points**:
- Chain commands with `;` and `&&` for efficiency
- Use `echo "=== SECTION ==="` markers to parse output
- Extract PR number from URL if provided
- **Capture PR body/description** - critical for context

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

### Phase 3: Analyze Code (Parallel with Task Tool)

**Use Task tool for parallel analysis** to maximize efficiency and speed.

Launch multiple Task agents **in parallel** (single message with multiple Task tool calls) to analyze different aspects:

**Task 1: File Context Analysis**
```
Prompt: "Read and analyze these changed files from the PR diff: [list 3-5 most critical files]. 
For each file:
- Read full file context to understand surrounding code
- Focus on the changed sections (lines [X-Y])
- Identify patterns, architecture decisions, and dependencies
- Note any established conventions being followed or violated
Return: Summary of each file's context, patterns found, and any concerns"
```

**Task 2: Codebase Pattern Search** (only if needed to validate concerns)
```
Prompt: "Search the codebase for:
- Similar patterns to [specific pattern from changed code]
- Existing tests related to [changed functionality]
- Established conventions for [specific concern - e.g., 'database queries', 'error handling']
Examples to find: [be specific about what to search for]
Return: Examples of how this is done elsewhere in the codebase with file:line references"
```

**Task 3: Security & Quality Scan**
```
Prompt: "Analyze this code diff for:
- Security issues: SQL injection, XSS, auth bypasses, data exposure
- Common bugs: null handling, edge cases, logic errors
- Performance problems: N+1 queries, inefficient algorithms
Focus only on changed code. Return: List of issues found with severity and line numbers"
```

**Example parallel Task usage**:
```markdown
I'll launch 3 analysis tasks in parallel:

*Launches Task 1, Task 2, Task 3 simultaneously in one message*

[Tasks complete and return results]

Based on the analysis:
- Task 1 found: [file context summary]
- Task 2 found: [pattern examples]
- Task 3 found: [security/quality issues]
```

**Important**: 
- Launch all Tasks in **single message** for true parallelism
- Be specific in Task prompts about what to find
- Only launch Task 2 (pattern search) if you need to validate a concern
- Skip Task 3 for trivial changes (typo fixes, documentation only)

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

**IMPORTANT**: Use **parallel Task tool** by default if you have **> 3 comments** to post.

**Decision tree**:
- **1-3 comments**: Use simple sequential bash commands
- **> 3 comments**: Use parallel Task tool (DEFAULT for efficiency)

**Method 1: Sequential (1-3 comments only)**
```bash
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 42; \
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 108; \
gh pr review <PR_NUMBER> --comment --body "$(cat <<'EOF'
## Overall Review Summary
[summary content]
EOF
)"
```

**Method 2: Parallel with Task Tool (> 3 comments - DEFAULT)**

Launch parallel Task agents to post comments simultaneously:

```markdown
I'll post these 7 comments in parallel using Task agents:

*Launch multiple Task agents in parallel (single message):*

Task 1: Post comments 1-3
Task 2: Post comments 4-6  
Task 3: Post comment 7 + summary

[After tasks complete]

✅ All comments posted successfully! View PR: [URL]
```

**Task prompt template**:
```
Task: "Post these inline comments to PR #[NUMBER]:

Comment 1:
- File: auth.ts
- Line: 42
- Body: [full comment text with markdown and watermark]

Comment 2:
- File: middleware.ts
- Line: 120
- Body: [full comment text with markdown and watermark]

Use gh pr comment to post each inline comment.
Return: Confirmation of posted comments with any errors"
```

**Parallel posting strategy**:
- Batch comments into groups (2-3 comments per Task)
- Launch all Tasks in single message
- One Task should post the summary comment
- Wait for all to complete before confirming to user

**Example with 7 comments**:
```markdown
*Launches 3 Tasks in parallel:*

Task 1: "Post comments 1-3 to PR #123" (auth.ts:42, middleware.ts:120, user-controller.ts:85)
Task 2: "Post comments 4-6 to PR #123" (auth.ts:200, user-service.ts:55, cache.ts:30)
Task 3: "Post comment 7 and summary to PR #123" (error-handler.ts:15 + overall summary)

[All Tasks execute simultaneously]
```

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

**Performance Issue**:
```markdown
⚠️ **Important - Performance Issue**

**Issue**: [e.g., N+1 query problem]

\`\`\`typescript
// Current (inefficient)
[exact code]
\`\`\`

**Why this matters**: [Impact with numbers]

**Fix**:
\`\`\`typescript
// Optimized version
[exact fix]
\`\`\`

**Impact**: [Quantified - "101 queries → 2 queries (50x faster)"]

**Learning**: [Performance principle]

---
*🤖 Generated by OpenCode Assistant*
```

**Architecture/Design**:
```markdown
⚠️ **Important - Architecture**

**Issue**: [e.g., Business logic in controller]

\`\`\`typescript
// Current (couples concerns)
[exact code]
\`\`\`

**Why this matters**: [Maintainability/testability impact]

**Fix**:
\`\`\`typescript
// Separated concerns
[exact fix]
\`\`\`

**Benefits**: [Testability, reusability, clarity]

**Learning**: [Design principle - SRP, DI, etc.]

---
*🤖 Generated by OpenCode Assistant*
```

**Readability**:
```markdown
💡 **Suggestion - Readability**

\`\`\`typescript
// Current
[code]
\`\`\`

\`\`\`typescript
// Suggested
[improved]
\`\`\`

**Why**: [Self-documenting, reduces cognitive load]

**Principle**: Code read 10x more than written

---
*🤖 Generated by OpenCode Assistant*
```

**Question**:
```markdown
❓ **Question - Design Decision**

I noticed [observation]. Was this because [reason]?

\`\`\`typescript
[code in question]
\`\`\`

**Trade-offs**:
- Current: [pros/cons]
- Alternative: [pros/cons]

Would love to understand your reasoning!

---
*🤖 Generated by OpenCode Assistant*
```

**Praise**:
```markdown
✅ **Great Implementation!**

[Specific praise]

\`\`\`typescript
[good code]
\`\`\`

[Why it's good - principle followed, problem solved] 🎯

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

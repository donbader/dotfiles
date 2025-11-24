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

### Phase 3: Analyze Code (Parallel Tool Usage)

Perform these analyses **in parallel** using multiple tool calls:

1. **Read changed files** (3-5 most critical files only)
   - Read full file context to understand surrounding code
   - Focus on changed sections, not entire file
   
2. **Search for related code** (only if needed)
   - Find similar patterns for validation
   - Look for existing tests
   - Identify established conventions
   
3. **Check documentation** (only if relevant)
   - Skip for small bug fixes

**Important**: Be selective - don't read everything speculatively.

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

**Choose implementation**:

**Option 1: Simple (< 10 comments)**
```bash
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 42; \
gh pr comment <PR_NUMBER> --body "..." --file path/to/file.ts --line 108; \
gh pr review <PR_NUMBER> --comment --body "$(cat <<'EOF'
## Overall Review Summary

**Overall assessment**: [2-3 sentences on code quality vs PR purpose]

**PR Purpose**: [From description]

**Strengths**:
- [What's done well]

**Focus areas**: Inline comments covering:
- 🚨 [X] Critical issues
- ⚠️ [X] Important improvements
- 💡 [X] Suggestions

**Next steps**:
1. [Most critical action]

**Future Considerations** (not blockers):
- [Broader refactoring opportunity]
- [Architecture improvement]
- [Technical debt]

*These are noted for future work, not blockers.*

---
*🤖 Generated by OpenCode Assistant*
EOF
)"
```

**Option 2: Parallel (10+ comments)**
```bash
pr_number=<PR_NUMBER>
commit_sha=$(gh pr view $pr_number --json headRefOid -q .headRefOid)
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
token=$(gh auth token)

post_comment() {
  curl -s -X POST \
    -H "Authorization: token $token" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$repo/pulls/$pr_number/comments" \
    -d "$(jq -n \
      --arg body "$1" \
      --arg commit "$commit_sha" \
      --arg path "$2" \
      --arg line "$3" \
      '{body: $body, commit_id: $commit, path: $path, line: ($line | tonumber)}'
    )" > /dev/null &
}

# Post all in parallel (each includes watermark)
post_comment "🚨 **Critical**: ...\n\n---\n*🤖 Generated by OpenCode Assistant*" "file.ts" "42"
post_comment "⚠️ **Important**: ...\n\n---\n*🤖 Generated by OpenCode Assistant*" "file.ts" "108"
wait

# Post summary
gh pr review $pr_number --comment --body "$(cat <<'EOF'
[Summary with Future Considerations section]
EOF
)"
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

**Critical Security**:
```markdown
🚨 **Critical - Security Issue**

**Issue**: [e.g., SQL injection vulnerability]

\`\`\`typescript
// Current code (vulnerable)
[exact code]
\`\`\`

**Why critical**: [Security risk and attack vector]

**Fix**:
\`\`\`typescript
// Secure version
[exact fix]
\`\`\`

**Learning**: [Security principle - e.g., parameterized queries]

**References**: [OWASP link, codebase example]

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

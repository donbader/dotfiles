---
name: git:review-pr-v2
description: Context-aware, educational code review for GitHub PRs
---

# Review GitHub Pull Request

Perform thorough, context-aware, educational code reviews that help developers learn and improve code quality through constructive feedback.

## Usage

```bash
# Review specific PR by URL
/git:review-pr-v2 https://github.com/owner/repo/pull/123

# Review PR for current branch (auto-detect)
/git:review-pr-v2
```

When a PR URL is provided as an argument, use that URL exclusively. Otherwise, auto-detect the PR for the current branch.

## Review Modes

The command intelligently detects the appropriate review mode:

**First Review** - No previous OpenCode reviews exist:
- Review entire PR diff with context gathering
- Apply two-pass review strategy (pattern detection → context analysis)
- Post comprehensive review with inline comments
- Present review to user for approval before posting

**Re-Review** - Unresolved threads exist:
- Fetches all review threads using GraphQL to check resolution status
- **CRITICAL**: Only verifies unresolved threads (`isResolved: false`)
- For each unresolved thread: Verifies fix, replies in-thread, marks resolved if addressed
- Reviews new commits since last review for additional issues
- Posts verification summary when all concerns addressed

**Incremental Review** - All previous threads resolved, new commits exist:
- Detects new commits since last OpenCode review
- **Only reviews the delta** (changes since last review commit)
- More focused - only comment on critical issues in new code
- If no new commits: exits early indicating PR is ready for merge

**All modes**: Never directly approve - always leave approval decision to the human reviewer

## Documentation Structure

This command is organized into the following modules:

### Core Concepts
- **{file:./review-pr-v2/principles.md}** - Review philosophy and core principles
  - Confidence-based severity levels
  - Scope management
  - Context awareness

### Implementation Phases
- **{file:./review-pr-v2/workflow-overview.md}** - Workflow overview and review modes
- **{file:./review-pr-v2/phase-1-setup-worktree.md}** - Phase 1: Setup Worktree
- **{file:./review-pr-v2/phase-2-fetch-info.md}** - Phase 2: Fetch PR Information
- **{file:./review-pr-v2/phase-3-gather-context.md}** - Phase 3: Gather Context
- **{file:./review-pr-v2/phase-4-analyze-context.md}** - Phase 4: Analyze PR Context
- **{file:./review-pr-v2/phase-5-analyze-code.md}** - Phase 5: Analyze Code
- **{file:./review-pr-v2/phase-6-two-pass-review.md}** - Phase 6: Two-Pass Review Strategy
- **{file:./review-pr-v2/phase-7-apply-filters.md}** - Phase 7: Apply Comment Filters
- **{file:./review-pr-v2/phase-8-post-review.md}** - Phase 8: Post Review
- **{file:./review-pr-v2/phase-9-cleanup.md}** - Phase 9: Cleanup Worktree
- **{file:./review-pr-v2/phase-10-confirm.md}** - Phase 10: Confirm Success

### Templates, Guidelines & CLI Reference
- **{file:./review-pr-v2/templates.md}** - Comment templates for all severity levels
  - High confidence critical issues
  - Medium confidence important issues
  - Low confidence suggestions
  - Questions for missing context
  
- **{file:./review-pr-v2/guidelines.md}** - Best practices and success criteria
  - Writing educational comments
  - Tone guidelines
  - Error handling
  - Edge cases

- **{file:./review-pr-v2/gh-commands.md}** - Reusable GitHub CLI commands
  - Fetching PR metadata and diffs
  - Creating reviews with inline comments
  - Re-review verification and thread resolution

## Quick Reference

### Severity Decision Tree

```
Found potentially dangerous pattern
  ↓
Does it appear in 5+ similar files in codebase?
  YES → 💡 Suggestion (likely intentional pattern)
  NO  ↓
     
Is there an explanatory comment nearby (within 5 lines)?
  YES → 💡 Suggestion or ❓ Question (author aware, needs clarity)
  NO  ↓
     
Does PR description mention constraints/trade-offs?
  YES → ⚠️ Important (frame as question acknowledging context)
  NO  ↓
     
Is this a well-known anti-pattern (SQL injection, XSS, etc.)?
  YES → 🚨 Critical (high confidence it's wrong)
  NO  → ⚠️ Important or ❓ Question (medium/low confidence)
```

### Severity Guidelines

| Severity | Confidence | When to Use |
|----------|-----------|-------------|
| 🚨 **Critical** | >90% | Dangerous pattern + uncommon in codebase + no explanatory context |
| ⚠️ **Important** | 60-90% | Potential issue BUT pattern exists elsewhere OR PR mentions constraints |
| 💡 **Suggestion** | 40-60% | Pattern common (5+ files) OR author has comment needing clarity |
| ❓ **Question** | <40% | Unclear if bug or design choice, need author to explain |

### Context Gathering Checklist

Before flagging Critical issues:
- ✅ Search related GitHub issues/PRs
- ✅ Check if pattern appears in 3+ similar files
- ✅ Look for explanatory comments (TODO, NOTE, HACK)
- ✅ Review PR description for constraints
- ✅ Apply two-pass review (detect → analyze)

### Review Philosophy

Every review should be a learning opportunity that improves developer skills.

**Core characteristics**:
- **Educational**: Explain WHY changes are needed, not just WHAT
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact files, line numbers, and code patterns
- **Balanced**: Acknowledge strengths AND identify improvements
- **Actionable**: Provide clear, implementable next steps
- **Focused**: Comment only on code within PR scope
- **Context-aware**: Understand PR intent and system constraints
- **Humble**: Acknowledge when missing context instead of asserting

---

**Remember**: Every review is a teaching opportunity. When uncertain, ask questions rather than make assertions.

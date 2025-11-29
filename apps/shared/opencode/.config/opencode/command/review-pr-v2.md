---
name: git:review-pr-v2
description: Context-aware, educational code review for GitHub PRs
---

# Review GitHub Pull Request

Perform thorough, context-aware, educational code reviews that help developers learn and improve code quality through constructive feedback.

## Execution Instructions

Execute the following phases in order. Read each phase file completely before executing the commands.

### Phase 1: Determine PR and Setup Environment

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-1-setup-worktree.md

This phase checks if the user provided a PR URL argument. If yes, uses it and creates worktree. If no, auto-detects from current branch.

### Phase 2: Fetch PR Information  

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-2-fetch-info.md

This phase fetches PR metadata, files changed, review threads, and diff using the `$pr_number` from Phase 1.

### Phase 3: Gather Context

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-3-gather-context.md

### Phase 4: Analyze Context

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-4-analyze-context.md

### Phase 5: Analyze Code

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-5-analyze-code.md

### Phase 6: Two-Pass Review

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-6-two-pass-review.md

### Phase 7: Apply Filters

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-7-apply-filters.md

### Phase 8: Post Review

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-8-post-review.md

### Phase 9: Cleanup

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-9-cleanup.md

### Phase 10: Confirm Success

Read and execute: @~/.config/opencode/command/review-pr-v2/phase-10-confirm.md

## Usage

```bash
# Review specific PR by URL
/git:review-pr-v2 $ARGUMENTS

# Review PR for current branch (auto-detect)
/git:review-pr-v2
```

## Reference Documentation

### Core Concepts
- **@~/.config/opencode/command/review-pr-v2/principles.md** - Review philosophy and core principles
- **@~/.config/opencode/command/review-pr-v2/workflow-overview.md** - Workflow overview and review modes

### Templates & Guidelines
- **@~/.config/opencode/command/review-pr-v2/templates.md** - Comment templates for all severity levels
- **@~/.config/opencode/command/review-pr-v2/guidelines.md** - Best practices and success criteria
- **@~/.config/opencode/command/review-pr-v2/gh-commands.md** - GitHub CLI command reference

## Quick Reference - Severity Levels

| Severity | Confidence | When to Use |
|----------|-----------|-------------|
| 🚨 **Critical** | >90% | Dangerous pattern + uncommon in codebase + no explanatory context |
| ⚠️ **Important** | 60-90% | Potential issue BUT pattern exists elsewhere OR PR mentions constraints |
| 💡 **Suggestion** | 40-60% | Pattern common (5+ files) OR author has comment needing clarity |
| ❓ **Question** | <40% | Unclear if bug or design choice, need author to explain |

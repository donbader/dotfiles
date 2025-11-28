# Review Guidelines and Best Practices

## Best Practices

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

## Error Handling

Common error scenarios and responses:

**General errors**:
- **No PR found**: Ask user for PR URL
- **Invalid URL format**: Show expected format example
- **PR closed/merged**: Ask if they want to review anyway
- **Insufficient permissions**: Suggest `gh auth login`
- **Empty diff**: Inform no changes to review
- **API rate limit**: Wait and retry with exponential backoff

**Worktree errors**:
- **Creation fails**: Check if branch exists, fetch if needed, ensure `.worktree` is writable
- **Cleanup fails**: Force remove and warn about manual cleanup if needed
- **Stale state**: Always create from `origin/$branch`, verify commit matches remote
- **Diff vs file mismatch**: Indicates stale worktree, run `git reset --hard origin/$pr_branch`

**Re-review specific**:
- **File moved/deleted**: Note in verification that file no longer exists
- **Line numbers shifted**: Use fuzzy matching or note code was restructured
- **All comments resolved**: Skip re-review, just check for new issues
- **No changes since last**: Warn user code hasn't changed

**Worktree state troubleshooting checklist**:
1. ✅ Verify on latest commit: `git log -1 --oneline`
2. ✅ Check for newer commits: `git log HEAD..origin/$pr_branch --oneline`
3. ✅ Verify file line counts: `wc -l suspicious_file.go`
4. ✅ Confirm base branch: `echo $base_branch`
5. ✅ If any fail: `git fetch origin $pr_branch && git reset --hard origin/$pr_branch`

**Critical reminders**:
- NEVER assume base branch is `main` or `master`
- ALWAYS query: `gh pr view $pr_number --json baseRefName -q .baseRefName`
- If `gh pr diff` line counts don't match files: worktree is stale

## Edge Cases

- **Large PRs (100+ files)**: Focus on critical changes, note scope limitation
- **Auto-generated code**: Skip package-lock.json, generated protobuf, etc.
- **Formatting-only changes**: Post positive comment noting no issues
- **WIP/Draft PRs**: Lighter review focusing on approach validation
- **Dependency updates**: Focus on changelog, security advisories, breaking changes

## Success Criteria

A successful review meets these requirements:

### First Review
- ✅ Presents review to user for approval BEFORE posting
- ✅ Includes OpenCode watermark on every comment and summary
- ✅ Posts as inline comments on specific lines with context
- ✅ Provides educational explanations with "why" not just "what"
- ✅ Offers concrete, actionable code examples
- ✅ Balances constructive criticism with genuine praise
- ✅ Gives clear, implementable next steps
- ✅ Feels like learning from an experienced developer

### Re-Review
- ✅ Fetches all review threads autonomously using GraphQL
- ✅ Filters to ONLY unresolved threads (`isResolved: false`)
- ✅ For each unresolved thread: Verifies, replies in-thread, marks resolved if fixed
- ✅ Reviews new commits since last review and posts in-thread comments for new issues
- ✅ Uses GraphQL to mark threads as resolved programmatically
- ✅ Posts verification summary when all concerns addressed (ready for human approval)
- ✅ Executes autonomously - no user approval needed for individual verification actions
- ✅ NEVER directly approves - always leaves approval to human reviewer

### Incremental Review
- ✅ Detects new commits since last OpenCode review
- ✅ Exits early if no new commits (reports PR ready for merge)
- ✅ Reviews ONLY the delta (commits since last review)
- ✅ More lenient - focuses on critical issues in new code only
- ✅ Avoids redundant review of already-approved code
- ✅ Provides clear summary of what was reviewed incrementally
- ✅ NEVER directly approves - always leaves approval to human reviewer

### Merge Readiness (for re-reviews and incremental reviews)
- ✅ ALL critical (🚨) issues verified fixed and threads resolved
- ✅ ALL important (⚠️) issues verified fixed and threads resolved
- ✅ NO new issues found in recent changes
- ✅ Code quality improved from previous review

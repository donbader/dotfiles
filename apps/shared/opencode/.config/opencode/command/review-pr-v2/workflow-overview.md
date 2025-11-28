# Workflow Overview

## First Review
1. **Setup**: Create worktree (if URL provided) or use current branch
2. **Fetch**: Get PR metadata, diff, and changed files
3. **Analyze**: Review code changes for issues (security, performance, architecture, testing, readability)
4. **Present**: Show proposed comments to user for approval
5. **Post**: Submit review to GitHub as single request with inline comments
6. **Cleanup**: Remove worktree if created

## Re-Review (Unresolved Threads)
1. **Detect**: Identify previous OpenCode review threads using GraphQL
2. **Filter**: Extract ONLY unresolved threads (`isResolved: false`) - skip already resolved ones
3. **Verify**: For each unresolved thread, check if issue is fixed
4. **Reply**: Post in-thread verification (resolved/not resolved)
5. **Mark**: Resolve threads that are fixed using GraphQL API
6. **Scan**: Review new commits since last review for additional issues
7. **Summarize**: Post verification summary if all concerns addressed
8. **Cleanup**: Remove worktree if created

## Incremental Review (All Resolved, New Commits)
1. **Detect**: All previous threads resolved, check for new commits
2. **Compare**: Get last review commit vs current HEAD
3. **Early Exit**: If no new commits, report PR ready for merge
4. **Delta Review**: If new commits exist, review only changes since last review
5. **Focus**: More lenient - only critical issues in new code
6. **Post**: Submit focused review on new changes only
7. **Cleanup**: Remove worktree if created

**Key distinctions**:
- ❌ **Skip**: Thread is marked as resolved (`isResolved: true`) - already verified
- ✅ **Verify**: Thread is unresolved (`isResolved: false`) - needs verification, even if it has author replies
- 💡 **Important**: Author replies do NOT automatically resolve threads - always check `isResolved` status
- 📝 **Incremental**: Only review commits added since last OpenCode review

**Verification summary criteria**: 
- ✅ All previous issues verified fixed and resolved
- ✅ No new issues in recent changes
- ➡️ Post standalone comment indicating PR is ready for human approval

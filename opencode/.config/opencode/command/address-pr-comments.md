---
name: git:address-comments
description: Address and resolve code review comments on GitHub PRs
---

# Address PR Review Comments

Interactively address code review comments on GitHub PRs by implementing suggested changes and responding to reviewers.

## Usage

**Command syntax**:
```bash
/git:address-comments [PR_URL]
```

**Examples**:
```bash
# Address comments on specific PR by URL
/git:address-comments https://github.com/owner/repo/pull/123

# Address comments on PR for current branch (auto-detect)
/git:address-comments
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

## Complete Workflow Example

**Addressing PR from URL** (uses worktree):
1. User provides PR URL → Create worktree for that PR's branch
2. Fetch PR comments and review threads
3. Present comments to user with suggested actions
4. Implement code changes based on user decisions
5. Reply to comments (reviewers will mark as resolved)
6. Push changes to remote
7. Clean up worktree → User's original work unchanged

**Addressing current branch** (no worktree):
1. Auto-detect PR from current branch
2. Fetch PR comments and review threads
3. Present comments to user with suggested actions
4. Implement code changes based on user decisions
5. Reply to comments (reviewers will mark as resolved)
6. Push changes to remote

## Philosophy

Addressing review comments should be:
- **Systematic**: Process comments in logical order (file-by-file or by priority)
- **Interactive**: User confirms each change before implementation
- **Educational**: Understand WHY changes are requested
- **Communicative**: Reply to reviewers with context about changes
- **Thorough**: Track which comments are addressed vs. deferred
- **Clean**: Keep commits focused and well-described

**Goal**: Efficiently address feedback while maintaining quality and clear communication with reviewers.

## Workflow

### Phase 1: Setup Worktree (if needed)

**IMPORTANT**: When addressing comments for a PR from a URL (not current branch), use git worktree to avoid disrupting user's work.

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
  worktree_dir="/tmp/pr-address-${pr_number}-$$"
  
  # Fetch PR branch and create worktree
  git fetch origin "$pr_branch:$pr_branch" 2>/dev/null || git fetch origin "$pr_branch"
  git worktree add "$worktree_dir" "$pr_branch"
  
  # Change to worktree directory
  cd "$worktree_dir"
  
  echo "=== Created worktree at $worktree_dir ==="
fi
```

### Phase 2: Fetch PR Comments

**Single bash command** to fetch all required data:

```bash
echo "=== PR_NUMBER ===" && echo "$pr_number" && \
echo "=== PR_METADATA ===" && gh pr view $pr_number --json title,body,author,url,headRefName && \
echo "=== REVIEW_COMMENTS ===" && gh api "repos/{owner}/{repo}/pulls/${pr_number}/comments" --jq '.[] | {id, path, line, body, user: .user.login, created_at, in_reply_to_id}' && \
echo "=== REVIEW_THREADS ===" && gh pr view $pr_number --json comments --jq '.comments[] | {id, body, author: .author.login, created_at}'
```

**Key data captured**:
- PR metadata (title, branch, URL)
- Inline code review comments with file paths and line numbers
- General PR discussion comments
- Comment IDs for replying and resolving

### Phase 3: Categorize and Present Comments

**Organize comments by**:
1. **File and line number** for inline comments
2. **Unresolved vs. resolved status**
3. **Type**: Suggestion, question, critical issue, praise

**Present to user** in this format:

```
## Review Comments for PR #[NUMBER]: [Title]

Found [X] unresolved comment threads:

### Critical Issues (require action)
1. 🚨 src/auth.ts:42 - SQL injection vulnerability
   By: @reviewer | Created: 2 hours ago
   "This query is vulnerable to SQL injection..."
   
   [Suggested action: Implement parameterized query]

2. ⚠️ src/user-service.ts:85 - N+1 query problem
   By: @reviewer | Created: 2 hours ago
   "This creates 101 DB calls for 100 posts..."
   
   [Suggested action: Add batch query]

### Questions/Discussions
3. ❓ src/config.ts:12 - Why polling instead of webhooks?
   By: @reviewer | Created: 1 hour ago
   "Is there a reason for polling? Webhooks would be more efficient..."
   
   [Suggested action: Reply with explanation]

### Suggestions
4. 💡 src/utils.ts:55 - Variable naming
   By: @reviewer | Created: 30 mins ago
   "Consider renaming `d` to `userProfiles` for clarity..."
   
   [Suggested action: Apply suggestion]

---
How would you like to proceed?
1. Address all comments automatically (where possible)
2. Go through comments one-by-one interactively
3. Address specific files only
4. Skip and just view comments
```

### Phase 4: Interactive Addressing

**For each comment, present options**:

```
Comment 1/4: src/auth.ts:42 - SQL injection vulnerability
---
"This query is vulnerable to SQL injection. Use parameterized queries instead."

Current code:
```typescript
const query = `SELECT * FROM users WHERE id = ${userId}`;
const result = await db.query(query);
```

Suggested fix (if available):
```typescript
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
```

Actions:
[1] Apply suggested fix
[2] Show me the file and I'll fix it manually
[3] Reply to reviewer (ask question or explain)
[4] Skip for now
[5] Mark as "won't fix" with reason

Your choice (1-5):
```

**User selection handling**:

**Option 1: Apply suggestion**
- If GitHub suggestion block exists, apply it directly
- If not, implement the fix based on the comment
- Show diff to user for confirmation
- Ask for commit message or use default: "fix: address review comment on {file}:{line}"

**Option 2: Manual fix**
- Read and display the file with context (±10 lines)
- User makes changes using Edit tool
- Confirm changes with diff
- Ask for commit message

**Option 3: Reply to reviewer**
- Prompt user: "What would you like to say?"
- Post reply via GitHub API
- Do NOT mark as resolved (let reviewer do this)

**Option 4: Skip**
- Add to "deferred" list
- Continue to next comment

**Option 5: Won't fix**
- Prompt user for reason
- Post reply with reason
- Do NOT mark as resolved (let reviewer do this)

### Phase 5: Implement Changes

**For each approved change**:

1. **Apply the code change** using Edit tool
2. **Show diff** to user for confirmation
3. **Create focused commit**:
   ```bash
   git add [modified_files]
   git commit -m "fix: address review - [brief description]
   
   Addresses comment by @reviewer on [file]:[line]
   - [What was changed]
   - [Why it was changed]"
   ```

**Batching strategy**:
- Group related changes in same file into one commit
- Keep unrelated changes in separate commits
- Use descriptive commit messages that reference the feedback

### Phase 6: Reply to Comments

**For each addressed comment**, post a reply:

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Reply to comment
gh api "repos/${repo_info}/pulls/comments/${comment_id}/replies" \
  --method POST \
  --field body="✅ **Addressed**

[Brief explanation of what was changed]

Fixed in commit: ${commit_sha}

---
*🤖 Generated by OpenCode*"
```

**Important**: Do NOT mark conversations as resolved via API. Let reviewers verify and resolve threads themselves after reviewing your changes.

**Reply templates**:

**For implemented fixes**:
```markdown
✅ **Addressed**

Implemented your suggestion - changed to use parameterized queries to prevent SQL injection.

Fixed in commit: abc123f

---
*🤖 Generated by OpenCode*
```

**For questions/explanations**:
```markdown
💬 **Response**

Good question! We're using polling here because of firewall restrictions in the customer's environment that prevent webhook delivery. This was discussed in JIRA-1234.

Happy to explore webhooks again once those restrictions are lifted.

---
*🤖 Generated by OpenCode*
```

**For won't fix**:
```markdown
📝 **Won't Fix**

[User's explanation of why this won't be changed]

Reason: [e.g., "This is intentional for backward compatibility with v1 API"]

---
*🤖 Generated by OpenCode*
```

### Phase 7: Push Changes

**After all changes are committed**:

```bash
# Push changes to remote
git push origin HEAD

echo "✅ Pushed ${commit_count} commits addressing review comments"
```

### Phase 8: Summary

**Display completion summary**:

```
✅ Review Comments Addressed

**Actions taken**:
- ✅ Implemented: 3 comments
- 💬 Replied: 1 comment
- ⏭️ Skipped: 1 comment
- 🚫 Won't fix: 0 comments

**Commits created**: 3
- abc123f: fix: address SQL injection vulnerability in auth
- def456g: refactor: implement batch query for user posts
- ghi789h: refactor: improve variable naming in utils

**Comments replied to**: 3/5 threads

**Next steps**:
- 1 comment still needs attention (src/config.ts:12)
- All changes have been pushed to remote
- Reviewers will be notified of your responses

View PR: [PR_URL]
```

### Phase 9: Cleanup Worktree

**CRITICAL**: If a worktree was created, clean it up after pushing changes.

```bash
if [ "$use_worktree" = true ]; then
  # Return to original directory
  cd - > /dev/null
  
  # Remove worktree
  git worktree remove "$worktree_dir" --force
  
  echo "=== Cleaned up worktree ==="
fi
```

## Advanced Features

### Smart Suggestion Detection

Detect and extract GitHub suggestion blocks:
```markdown
```suggestion
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
```
```

Apply these directly to the file at the specified line number.

### Batch Operations

Allow user to apply multiple suggestions at once:
```
Apply all non-controversial suggestions? (y/n)
- ✅ Variable renaming (3 comments)
- ✅ Import organization (2 comments)
- ⏭️ Skipping architectural changes (requires discussion)
```

### Comment Prioritization

Sort comments by priority:
1. **Critical** (🚨): Security, bugs, breaking changes
2. **Important** (⚠️): Performance, architecture violations
3. **Suggestions** (💡): Readability, best practices
4. **Questions** (❓): Discussions, clarifications

### Conflict Detection

Before applying changes, check for conflicts:
- Has the file been modified since the comment was made?
- Has the line number changed due to other commits?
- Warn user and show current state vs. commented state

## Error Handling

Common error scenarios:

- **No PR found**: Ask user for PR URL
- **No comments found**: Inform user all comments are resolved
- **Comment line no longer exists**: Warn user and show current file state
- **Push fails**: Check for conflicts, suggest pulling first
- **Permission errors**: Ensure `gh auth` has proper scopes
- **Worktree creation fails**: Clean up and retry
- **Git conflicts**: Guide user through manual resolution

## Edge Cases

Special scenarios to handle:

- **Outdated comments**: Comments on lines that have changed - show diff
- **Resolved threads**: Option to view and re-open if needed
- **Multiple reviewers**: Group by reviewer, show consensus
- **Suggestion conflicts**: Multiple reviewers suggest different changes
- **Large PRs**: Allow filtering by file or reviewer
- **Draft PRs**: Handle appropriately, note that reviews may be preliminary

## Best Practices

### Communication

- **Always reply** when addressing a comment, even if just "Fixed ✅"
- **Explain why** for "won't fix" decisions
- **Ask clarifying questions** if comment is unclear
- **Thank reviewers** for helpful suggestions
- **Be respectful** in all responses

### Code Quality

- **Review before committing**: Always show diff for user confirmation
- **Keep commits focused**: One logical change per commit
- **Write good commit messages**: Reference what comment was addressed
- **Test your changes**: Ensure fixes don't break anything
- **Run linters/tests**: Before pushing changes

### Efficiency

- **Batch related changes**: Combine small changes in same file
- **Use suggestions directly**: When available and correct
- **Skip non-issues**: Don't waste time on resolved/invalid comments
- **Defer big changes**: Mark for separate PR if out of scope

## Success Criteria

A successful comment resolution session meets:

- ✅ All critical comments addressed or explicitly deferred
- ✅ Replies posted for all addressed comments
- ✅ Commits are focused and well-described
- ✅ Changes pushed to remote successfully
- ✅ Reviewers can verify changes and mark conversations as resolved
- ✅ Clear summary provided to user
- ✅ Worktree cleaned up (if used)

---

**Remember**: Review comments are opportunities to improve code quality and learn from others. Address them thoughtfully and communicate clearly.

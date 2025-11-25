---
name: git:sync-pr
description: Sync PR title and description for existing PR based on latest changes
---

# Sync GitHub Pull Request

Update an existing GitHub PR's title and description based on the latest commits and code changes.

## Branch Name Format
Expected format: `STRAITSX-1234/my-service-do-something`
- JIRA ID: `STRAITSX-1234` (required)
- Service: `my-service` (extracted from first segment after `/` up to first `-`)
- Description: `do-something` (remaining segments after service name)

**Edge cases:**
- No service name (e.g., `STRAITSX-1234/hotfix`): Use scope from actual changes
- Invalid JIRA ID format: Ask user for clarification

## PR Title Format
`[JIRA-ID] type(service): <description>`

**Auto-generate the title by:**
1. Analyzing all commits and code changes in the branch
2. Determining the primary purpose and scope of changes
3. Crafting a clear, concise description (max 72 characters total for title)
4. Using imperative mood (e.g., "Add feature" not "Added feature")

**Do NOT simply format the branch name.** Create a meaningful title that accurately describes what the PR actually does.

## Workflow

1. **Validate prerequisites:**
   - Confirm current branch is not `main`
   - Verify a PR exists for current branch
   - Check if branch name matches expected format

2. **Gather information using Bash tool** (execute all these commands in a single Bash call):
   - Get current branch name: `git rev-parse --abbrev-ref HEAD`
   - Get PR number for current branch: `gh pr view --json number -q .number`
   - Get current PR title and body: `gh pr view --json title,body -q '{title: .title, body: .body}'`
   - Get commit history: `git log main..HEAD`
   - Get code changes: `git diff main...HEAD`
   
   **IMPORTANT**: Use a single Bash tool call with multiple commands chained together using `&&` or `;`.

3. **Parse branch name** to extract:
   - JIRA ID (e.g., `STRAITSX-1234`)
   - Service name (e.g., `my-service` - first segment after `/` before first `-`)
   - Branch description (remaining segments)
   - Handle edge cases where service name may be missing

4. **Analyze commits and changes** to understand:
   - Review ALL commit messages since diverging from main
   - Read actual code changes using git diff
   - Identify the main purpose and impact of the PR
   - Determine PR type:
     - `feat` - New functionality or feature additions
     - `fix` - Bug fixes and error corrections
     - `refactor` - Code restructuring without behavior changes
     - `docs` - Documentation only changes
     - `test` - Test additions or updates
     - `chore` - Build process, tooling, or dependency updates

5. **Generate PR title** based on actual changes:
   - Format: `[JIRA-ID] type(service): clear description`
   - Example: `[STRAITSX-1234] feat(auth-service): Add OAuth2 token validation`
   - Description should reflect what was actually implemented, not branch name
   - Keep total title under 72 characters
   - Use imperative mood
   - Be specific and meaningful

6. **Generate PR description** with this structure:

   ```markdown
   ## JIRA Ticket
   [STRAITSX-1234](https://fazzfinancial.atlassian.net/browse/STRAITSX-1234)

   ## Summary
   [2-3 sentences explaining WHAT was changed and WHY. Focus on business value and context, not implementation details]

   ## Changes
   [List key technical changes organized by area/file. Be specific about what was modified]
   - **[Area/Component]**: [Specific change and reason]
   - **[Area/Component]**: [Specific change and reason]
   - **[Area/Component]**: [Specific change and reason]

   ## Testing
   [Describe how changes were verified - unit tests, integration tests, manual testing]
   - [ ] Unit tests added/updated
   - [ ] Integration tests added/updated
   - [ ] Manual testing completed
   - [ ] Edge cases considered

   ## Deployment Notes
   [Any special considerations for deployment - remove section if none apply]
   - [ ] Database migrations required
   - [ ] Configuration changes needed
   - [ ] Breaking changes (document what breaks)
   - [ ] Feature flags involved
   - [ ] Dependencies updated

   ## Reviewer Focus
   [Guide reviewers on what to pay attention to]
   - [Specific area or concern to review carefully]
   - [Trade-offs or design decisions made]
   - [Areas where feedback is particularly wanted]

   ```
   
   **Important guidelines:**
   - Preserve manually added content when possible (e.g., testing details, deployment notes)
   - Write descriptions in complete sentences with proper context
   - Be specific - avoid vague terms like "updated", "fixed", "improved" without details
   - Use checkboxes `[ ]` for items that need verification
   - Remove sections that don't apply rather than leaving them empty
   - Focus on WHY changes were made, not just WHAT changed
   - Customize the JIRA URL template for your organization if needed

7. **Update the PR** using Bash tool:
   ```bash
   gh pr edit <PR_NUMBER> --title "..." --body "..."
   ```

## Important Notes

- **Title must be based on actual changes, NOT branch name formatting**
- **Use single Bash tool calls with chained commands** (`&&` or `;`) for efficiency
- Analyze ALL commits in the branch, not just the latest one
- Read the actual code diff to understand what was implemented
- Determine the most appropriate type based on the overall change
- Make both title and description meaningful by analyzing real changes
- **Preserve user-added content** when syncing (e.g., checked boxes, specific testing notes)
- Confirm success and show the PR URL when done

## Smart Merging Strategy

When updating an existing PR description:
1. **Always update**: JIRA Ticket, Summary, Changes sections (regenerate from latest commits)
2. **Preserve if present**: Testing checkboxes that are checked, Deployment Notes with specific details
3. **Merge intelligently**: If user added custom sections or notes, append them after standard sections
4. **Ask before overwriting**: If PR has significant custom content, confirm with user before replacing

## Error Handling

- If no PR exists for current branch, inform user and suggest using `git:create-pr` instead
- If branch is `main`, abort and inform user
- If branch name doesn't match expected format, ask user for clarification
- If JIRA ID format is invalid, request correct format from user
- If `gh pr view` fails, check if PR was closed or deleted and inform user

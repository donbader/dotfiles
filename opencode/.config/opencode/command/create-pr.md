---
name: git:create-pr
description: Create GitHub PR with auto-generated title and description from branch name
---

# Create GitHub Pull Request

Automatically create a GitHub PR with a well-formatted title and description based on the branch name.

## Branch Name Format
Expected format: `STRAITSX-1234/my-service-do-something`
- JIRA ID: `STRAITSX-1234`
- Service: `my-service`
- Description: `do-something`

## PR Title Format
`[JIRA-ID] type(service): <description>`

**Auto-generate the title by:**
1. Analyzing all commits and code changes in the branch
2. Determining the primary purpose and scope of changes
3. Crafting a clear, concise description (50-72 chars max)
4. Using imperative mood (e.g., "Add feature" not "Added feature")

**Do NOT simply format the branch name.** Create a meaningful title that accurately describes what the PR actually does.

## Workflow

1. **Gather information in parallel using Bash tool** (execute all these commands in a single Bash call):
   - Get current branch name: `git rev-parse --abbrev-ref HEAD`
   - Get commit history: `git log main..HEAD`
   - Get code changes: `git diff main...HEAD`
   - Check remote tracking: `git status -sb`
   
   **IMPORTANT**: Use a single Bash tool call with multiple commands separated by `&&` or `;` to execute in parallel.

2. **Parse branch name** to extract:
   - JIRA ID (e.g., `STRAITSX-1234`)
   - Service name (e.g., `my-service`)
   - Branch description

3. **Analyze commits and changes** to understand:
   - Review ALL commit messages since diverging from main
   - Read actual code changes using git diff
   - Identify the main purpose and impact of the PR
   - Determine PR type (feat, fix, refactor, docs, test, chore)

4. **Generate PR title** based on actual changes:
   - Format: `[JIRA-ID] type(service): clear description`
   - Example: `[STRAITSX-1234] feat(auth-service): Add OAuth2 token validation`
   - Description should reflect what was actually implemented, not branch name
   - Keep under 72 characters
   - Use imperative mood
   - Be specific and meaningful

5. **Generate PR description** with this structure:

   ```markdown
   ## JIRA Ticket
   [STRAITSX-1234](https://fazzfinancial.atlassian.net/browse/STRAITSX-1234)

   ## Summary
   Brief overview of what this PR does (2-3 sentences)

   ## Changes
   - Bullet point of key change 1
   - Bullet point of key change 2
   - Bullet point of key change 3

   ```

6. **Push and create PR**:
   - Push branch to remote if needed: `git push -u origin HEAD`
   - Create the **draft** PR with self-assignment: `gh pr create --draft --title "..." --body "..." --assignee @me`
   
   **IMPORTANT**: If both push and PR creation are needed, use a single Bash tool call with both commands separated by `&&`.

## Important Notes

- If branch name doesn't match expected format, ask user for clarification
- **Title must be based on actual changes, NOT branch name formatting**
- **Use single Bash tool calls with multiple commands** to maximize parallel execution efficiency
- Analyze ALL commits in the branch, not just the latest one
- Read the actual code diff to understand what was implemented
- Determine the most appropriate type based on the overall change
- Make both title and description meaningful by analyzing real changes
- Push branch to remote if needed before creating PR
- Return the PR URL when done

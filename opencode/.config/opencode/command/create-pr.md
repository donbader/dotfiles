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

1. **Get current branch name**
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

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

6. **Create the PR**:
   ```bash
   gh pr create --title "..." --body "..." --assignee @me
   ```

## Important Notes

- If branch name doesn't match expected format, ask user for clarification
- **Title must be based on actual changes, NOT branch name formatting**
- Analyze ALL commits in the branch, not just the latest one
- Read the actual code diff to understand what was implemented
- Determine the most appropriate type based on the overall change
- Make both title and description meaningful by analyzing real changes
- Push branch to remote if needed before creating PR
- Return the PR URL when done

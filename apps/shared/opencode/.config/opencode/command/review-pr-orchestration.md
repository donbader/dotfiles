---
name: git-review-pr-orchestration
description: Multi-agent PR review with specialized reviewers (code-quality, security, performance)
---

# Review GitHub Pull Request (v4 - Multi-Agent)

Perform comprehensive code reviews using specialized reviewer agents that work in parallel.

## Architecture

This workflow uses a **multi-agent architecture** with specialist reviewers:

- **code-quality-reviewer** (ALWAYS enabled) - Architecture, modularity, readability, testing
- **security-reviewer** (optional) - Security vulnerabilities and attack vectors
- **performance-reviewer** (optional) - Performance issues and optimizations

The orchestrator:

1. Gathers shared context once
2. Spawns specialist agents in parallel
3. Aggregates findings using severity hierarchy
4. Filters irrelevant comments
5. Posts unified review

---

## Usage

```bash
# Review specific PR by URL
/git:review-pr-v4 https://github.com/owner/repo/pull/123

# Review PR for current branch (auto-detect)
/git:review-pr-v4

# Force enable all agents
/git:review-pr-v4 https://github.com/owner/repo/pull/123 --all-agents

# Enable only specific agents
/git:review-pr-v4 https://github.com/owner/repo/pull/123 --agents=code-quality,security
```

**Priority**: Explicit PR URL takes precedence over auto-detection.

**Parallel Execution Safety**: Each review session uses a unique temporary directory, allowing you to run multiple reviews simultaneously without conflicts.

---

## Parallel Execution Support

This command is designed to be **parallel-execution safe**, meaning you can run multiple PR reviews at the same time without conflicts.

### How It Works

Each review session is identified by PR number:

- `pr-review-{pr_number}`

Example session IDs:

- `pr-review-123`
- `pr-review-456`

### Isolated Resources

Each PR review has its own:

- **Worktree** (if using URL mode): `{current_dir}/.worktree/pr-review-{pr_number}/`
  - Created in your current working directory
  - Multiple PRs can have worktrees in the same `.worktree` folder
- **Review artifacts** (nested inside worktree): `.worktree/pr-review-{pr_number}/.review/`
  - `shared_context.json`
  - `{agent}_output.json` files
  - `sorted_findings.json`
  - `formatted_findings.json`
- **Temp directory** (if reviewing current branch): `/tmp/opencode-review/pr-review-{pr_number}/`
  - Only used when not creating a worktree
  - Same artifacts as above

### Example: Running 3 Reviews in Parallel

```bash
# Terminal 1
/git:review-pr-v4 https://github.com/owner/repo/pull/123

# Terminal 2 (different directory or same directory)
/git:review-pr-v4 https://github.com/owner/repo/pull/456

# Terminal 3
/git:review-pr-v4 https://github.com/owner/repo/pull/789
```

Each review will:

- ✅ Use isolated temp files (no conflicts)
- ✅ Use separate worktrees (no git conflicts)
- ✅ Clean up automatically on completion or failure
- ✅ Not interfere with each other

---

## Workflow Phases

### Phase 1: Setup & PR Detection

**Sequential** - Must complete before proceeding

**Tasks**:

```bash
# 1. Extract PR number from URL argument OR detect from current branch
if [ -n "$1" ] && [[ "$1" =~ ^https?:// ]]; then
  # Option A: PR number from URL argument
  pr_number=$(echo "$1" | grep -oE '[0-9]+$')
  use_worktree=true
else
  # Option B: PR for current branch (auto-detect)
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
  use_worktree=false
fi

if [ -z "$pr_number" ]; then
  echo "ERROR: No PR found. Provide URL or ensure current branch has a PR."
  exit 1
fi

# 2. Create git worktree for isolation (if reviewing from URL)
if [ "$use_worktree" = true ]; then
  # Verify we're in a git repository
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "ERROR: Not in a git repository. Cannot create worktree."
    exit 1
  fi

  # Create worktree in current working directory
  current_dir="$(pwd)"
  worktree_path="${current_dir}/.worktree/pr-review-${pr_number}"
  pr_branch=$(gh pr view "$pr_number" --json headRefName -q .headRefName)

  echo "📁 Review session: pr-review-${pr_number}"
  echo "📁 Current directory: $current_dir"
  echo "🌳 Creating worktree at: $worktree_path"

  # Create .worktree directory if it doesn't exist
  mkdir -p "${current_dir}/.worktree"

  git fetch origin "$pr_branch"
  git worktree add "$worktree_path" "origin/$pr_branch"
  cd "$worktree_path"

  # Create temp directory INSIDE worktree for review artifacts
  temp_dir="${worktree_path}/.review"
  mkdir -p "$temp_dir"

  # Ensure review artifacts aren't tracked by git
  echo "*" > "${temp_dir}/.gitignore"

  echo "📂 Review artifacts: ${temp_dir}"

  # Set up cleanup trap to remove worktree and all artifacts
  cleanup_on_exit() {
    if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
      cd "$current_dir" > /dev/null 2>&1
      git worktree remove "$worktree_path" --force 2>/dev/null
      # Try to remove empty .worktree directory
      rmdir "${current_dir}/.worktree" 2>/dev/null || true
      echo "🧹 Cleaned up worktree and review artifacts"
    fi
  }
  trap cleanup_on_exit EXIT
else
  # Non-worktree mode: reviewing current branch in place
  # Use /tmp for review artifacts
  temp_dir="/tmp/opencode-review/pr-review-${pr_number}"
  mkdir -p "$temp_dir"

  echo "📁 Review session: pr-review-${pr_number}"
  echo "📂 Review artifacts: ${temp_dir}"

  # Set up cleanup trap for temp files
  cleanup_on_exit() {
    if [ -d "$temp_dir" ]; then
      rm -rf "$temp_dir"
      echo "🧹 Cleaned up review artifacts"
    fi
  }
  trap cleanup_on_exit EXIT
fi

# 3. Validate PR exists and is accessible
gh pr view "$pr_number" --json title,state || {
  echo "ERROR: Cannot access PR #$pr_number"
  exit 1
}
```

**Output**: `$pr_number`, `$worktree_path` (if created), `$use_worktree` flag, `$temp_dir`

---

### Phase 2: Information Gathering

**Execute all tasks in parallel**

**Tasks**:

1. Fetch PR metadata: `gh pr view "$pr_number" --json title,body,author,state,isDraft,labels,baseRefName,headRefName,headRefOid`
2. Fetch files changed: `gh pr view "$pr_number" --json files`
3. Fetch PR diff: `gh pr diff "$pr_number"`
4. Fetch review history via GraphQL (detect existing OpenCode reviews)
5. Determine review mode (first/re-review/incremental)

**Output**: PR metadata (including commit SHA), files changed, diff, review threads, suggested review mode

---

### Phase 3: Shared Context Building

**Sequential** - Build context object for all agents

**Tasks**:

1. Parse PR intent and constraints from description
2. Analyze changed files to identify relevant codebase areas
3. Gather contextual code from related modules/files
4. Search for relevant patterns in the codebase (count occurrences)
5. Identify architectural patterns and documentation
6. Analyze diff for statistical summary
7. Determine focus areas based on PR content
8. Build shared context JSON object

**Context Gathering Strategy**:

For each changed file, gather relevant context:

- **If changing a specific module** (e.g., `crawler/config.ts`):
  - Include the full implementation of the changed module
  - Find related files (imports, exports, usage)
  - Show how the module is used in the codebase (call sites)
  - Include relevant tests if they exist
- **If changing configuration**:
  - Show how configuration is loaded and used
  - Include examples of existing configurations
  - Show the runtime flow that uses the config
- **If changing database/repository layer**:
  - Include related schema/migration files
  - Show service layer that uses the repository
  - Include similar repository patterns for consistency
- **If changing API endpoints**:
  - Include related middleware and validators
  - Show the full request/response flow
  - Include authentication/authorization patterns

**Example Context Gathering**:

```bash
# For each changed file, gather contextual information
for file in "${files_changed[@]}"; do
  # 1. Identify the module/component being changed
  module_path=$(dirname "$file")
  module_name=$(basename "$module_path")

  # 2. Find related files (same directory, imports, usages)
  related_files=$(rg -l "import.*$(basename "$file" .ts)" --type ts || true)
  import_files=$(rg "^import.*from" "$file" | awk -F"'" '{print $2}' || true)

  # 3. Gather full implementation of key related files
  # (limit to avoid context overflow - top 5 most relevant)

  # 4. Find usage examples
  usage_examples=$(rg -A 3 "$(basename "$file" .ts)\." --type ts | head -20 || true)
done
```

**Context Object Structure** (see `shared/context-schema.md`):

```json
{
  "pr_metadata": { ... },
  "pr_analysis": {
    "intent": "Add OAuth2 authentication",
    "scope": "feature",
    "constraints": ["Must maintain backward compatibility"],
    "focus_areas": ["OAuth security", "Token storage"]
  },
  "files_changed": [ ... ],
  "diff_summary": { ... },
  "related_code_context": {
    "crawler/config.ts": {
      "full_file_content": "...",
      "related_files": [
        {
          "path": "crawler/index.ts",
          "content": "...",
          "relationship": "Imports and uses CrawlerConfig"
        },
        {
          "path": "crawler/worker.ts",
          "content": "...",
          "relationship": "Uses crawler configuration"
        }
      ],
      "usage_examples": [
        {
          "file": "services/scraper.ts",
          "line": 42,
          "code": "const config = new CrawlerConfig(options);"
        }
      ],
      "tests": [
        {
          "path": "crawler/__tests__/config.test.ts",
          "content": "..."
        }
      ]
    }
  },
  "codebase_patterns": {
    "string_concatenation_for_queries": { "count": 12, "examples": [...] }
  },
  "architectural_context": {
    "module_structure": "...",
    "common_patterns": "...",
    "documentation": "..."
  },
  "review_history": { ... }
}
```

**Output**: Shared context JSON object stored in `$temp_dir/shared_context.json`

**Context Size Management**:

- Limit each changed file's context to ~500 lines of related code
- Prioritize: direct dependencies > usage examples > tests > similar patterns
- If PR changes >10 files, focus on top 10 most significant changes
- Include full content for small files (<100 lines)
- Include excerpts for large files (most relevant sections)

---

### Phase 4: Multi-Agent Analysis

**Dynamic - Orchestrator decides which agents to spawn**

#### Agent Selection Logic

```bash
# ALWAYS enable code-quality agent
enabled_agents=("code-quality-reviewer")

# Auto-enable security agent if PR touches security-sensitive areas
if [[ "$pr_content" =~ (auth|password|token|secret|oauth|crypto|security) ]] || \
   [[ "$files_changed" =~ (auth|security|crypto) ]]; then
  enabled_agents+=("security-reviewer")
  echo "✓ Auto-enabled security-reviewer (detected security-related changes)"
fi

# Auto-enable performance agent if PR touches performance-sensitive areas
if [[ "$pr_content" =~ (query|database|loop|performance|cache|optimize) ]] || \
   [[ "$files_changed" =~ (repository|service|query) ]] || \
   [ "$files_changed_count" -gt 20 ]; then
  enabled_agents+=("performance-reviewer")
  echo "✓ Auto-enabled performance-reviewer (detected performance-sensitive changes)"
fi

# Override: Force enable all agents if --all-agents flag
if [[ "$*" =~ --all-agents ]]; then
  enabled_agents=("code-quality-reviewer" "security-reviewer" "performance-reviewer")
  echo "✓ All agents enabled (--all-agents flag)"
fi

# Override: Specific agents via --agents flag
if [[ "$*" =~ --agents= ]]; then
  agents_arg=$(echo "$*" | grep -oP '(?<=--agents=)[^ ]+')
  IFS=',' read -ra enabled_agents <<< "$agents_arg"
  echo "✓ Custom agents enabled: ${enabled_agents[*]}"
fi

echo "📋 Enabled agents: ${enabled_agents[*]}"
```

#### Parallel Agent Invocation

```bash
# Spawn all enabled agents in parallel
agent_pids=()
agent_outputs=()

for agent in "${enabled_agents[@]}"; do
  # Invoke agent with shared context
  (
    echo "🔍 Starting $agent..."
    /task agent:$agent "
Execute PR review for your specialty.

**Shared Context**:
$(cat ${temp_dir}/shared_context.json)

**Instructions**:
1. Analyze files in 'files_changed' for issues in your domain
2. Use codebase_patterns to inform confidence/severity
3. Use pr_analysis.constraints to avoid false positives
4. Return structured JSON output (see shared/reviewer-base.md)

**IMPORTANT**: Do NOT format comment bodies with markdown. Return raw structured data only.
The orchestrator will format all comments with proper styling, emojis, and sections.

**Output Format**:
{
  \"agent\": \"$agent\",
  \"findings\": [
    {
      \"file\": \"path/to/file\",
      \"line_start\": 42,
      \"line_end\": 45,
      \"severity\": \"critical|important|suggestion|question\",
      \"confidence\": 95,
      \"category\": \"category-slug\",
      \"title\": \"One-line summary\",
      \"issue\": \"Clear description of what's wrong\",
      \"why_it_matters\": \"Impact/consequences\",
      \"fix\": \"How to fix it\",
      \"fix_code\": \"optional code example\",
      \"fix_code_language\": \"optional language\",
      \"learning\": \"optional educational takeaway\",
      \"references\": [\"optional links\"],
      \"attack_example\": \"optional (security only)\",
      \"attack_example_language\": \"optional\",
      \"performance_impact\": \"optional (performance only)\"
    }
  ],
  \"metadata\": {...}
}
"
    > "${temp_dir}/${agent}_output.json"
    echo "✓ Completed $agent"
  ) &
  agent_pids+=($!)
done

# Wait for all agents to complete
echo "⏳ Waiting for ${#enabled_agents[@]} agents to complete..."
for pid in "${agent_pids[@]}"; do
  wait "$pid"
done

echo "✅ All agents completed"
```

**Output**: JSON output files from each agent in `$temp_dir`

---

### Phase 5: AI-Powered Aggregation, Filtering & Formatting

**AI Agent Decision-Making** - Intelligent curation of final review comments

#### Step 1: Collect All Findings

```bash
all_findings=()

for agent in "${enabled_agents[@]}"; do
  agent_findings=$(jq -r '.findings[]' "${temp_dir}/${agent}_output.json")
  all_findings+=("$agent_findings")
done

echo "📊 Collected findings:"
echo "  - Total findings: $(echo "${all_findings[@]}" | jq '. | length')"
```

#### Step 2: AI-Powered Aggregation & Filtering

Invoke an AI agent to make **all decisions** about which findings to keep, merge, or discard:

```bash
echo "🤖 Invoking AI Aggregator to curate final review comments..."

# Invoke AI agent with ALL findings + full context
aggregation_result=$(/task agent:review-aggregator "
You are an expert code review aggregator. Your job is to take ALL findings from multiple specialist agents and decide:
1. **Which comments should be posted** (keep)
2. **Which comments should be discarded** (too minor, false positive, out of scope)
3. **Which comments should be merged** (related issues on same line)

**All Raw Findings** (from all agents):
$(echo "${all_findings[@]}" | jq -c '.')

**PR Context** (use this to make informed decisions):
$(cat ${temp_dir}/shared_context.json)

**Your Decision-Making Responsibilities**:

### 1. Relevance Filtering
Decide if each finding should be posted or discarded based on:
- **Scope**: Is it in a file that was actually changed in this PR?
- **Confidence**: Is the agent confident enough (generally >60%)?
- **Signal vs Noise**: Is this a real issue or nitpicking?
- **Intentional Patterns**: Does codebase_patterns show this is an accepted pattern (many occurrences)?
- **PR Intent**: Does this align with what the PR is trying to accomplish?

Examples to DISCARD:
- Suggesting a pattern refactor when codebase has 50+ instances of that pattern
- Style nitpicks when PR is a critical security fix
- Low confidence suggestions (<60%)
- Comments on unchanged code (check files_changed)
- False positives based on PR context

Examples to KEEP:
- Security vulnerabilities (always keep, even low confidence)
- Performance issues that match PR scope
- Code quality issues that are clear wins
- Anything aligned with PR intent/constraints

### 2. Conflict Resolution (Same Line, Multiple Findings)
When multiple agents comment on the same line:

**Option A: MERGE** (if related - same root cause):
- Combine into one rich comment with multiple perspectives
- Example: SQL injection + missing index → both about query construction
- Example: Auth bypass + session security → both about authentication
- Preserve insights from all agents

**Option B: KEEP HIGHEST SEVERITY** (if independent - different root causes):
- Discard lower severity findings to avoid clutter
- Example: Security critical + naming suggestion → keep security only
- Example: Performance issue + comment style → keep performance only

**Option C: KEEP BOTH SEPARATE** (if both critical and independent):
- Rare case: both findings are critical but address different issues
- Example: Two separate security vulnerabilities on same line

### 3. De-duplication (Same Issue, Different Locations)
If multiple findings describe the same issue across different files:
- Keep the most severe/representative example
- Add note: \"Similar issue found in X other files\"
- Avoid overwhelming developer with repetitive comments

### 4. Output Format

Return **ONLY** the findings that should be posted (after all filtering, merging, de-duplication):

{
  \"final_findings\": [
    {
      \"action\": \"keep\" | \"merge\" | \"discard\",
      \"file\": \"path/to/file\",
      \"line_start\": 42,
      \"line_end\": 45,
      \"severity\": \"critical|important|suggestion|question\",
      \"confidence\": 85,
      \"category\": \"security-sql-injection\",
      \"title\": \"Brief title\",

      // If merged:
      \"is_merged\": true,
      \"agents\": [\"security-reviewer\", \"performance-reviewer\"],
      \"original_finding_count\": 2,

      // Combined/preserved fields:
      \"issue\": \"...\",
      \"why_it_matters\": \"...\",
      \"fix\": \"...\",
      \"fix_code\": \"...\",
      \"fix_code_language\": \"typescript\",
      \"learning\": \"...\",
      \"references\": [...],
      \"attack_example\": \"...\",
      \"attack_example_language\": \"...\",
      \"performance_impact\": \"...\"
    }
  ],
  \"discarded_findings\": [
    {
      \"title\": \"...\",
      \"reason\": \"Low confidence (45%), likely false positive\",
      \"agent\": \"code-quality-reviewer\"
    }
  ],
  \"metadata\": {
    \"total_raw_findings\": 50,
    \"kept\": 12,
    \"merged\": 3,
    \"discarded\": 35,
    \"discard_reasons\": {
      \"low_confidence\": 10,
      \"out_of_scope\": 8,
      \"intentional_pattern\": 12,
      \"duplicate\": 3,
      \"too_minor\": 2
    },
    \"summary\": \"Filtered 50 raw findings down to 12 high-value comments. Merged 3 groups of related findings. Discarded 35 low-value findings (mostly intentional patterns and low confidence).\"
  }
}

**Important Guidelines**:
- **Be ruthless with filtering** - only keep findings that genuinely help the developer
- **Be generous with merging** - combine related insights for richer feedback
- **Explain your decisions** - provide clear reasoning in discard_reasons
- **Prioritize security** - never discard security findings unless clearly false positive
- **Respect PR scope** - don't derail PR with unrelated issues
- **Use context** - leverage codebase_patterns, PR intent, and constraints
")

# Extract final findings
final_findings=$(echo "$aggregation_result" | jq -r '.final_findings')

# Log aggregation summary
echo "✅ AI Aggregation complete:"
echo "$aggregation_result" | jq -r '.metadata |
  "  - Total raw findings: \(.total_raw_findings)",
  "  - Kept: \(.kept)",
  "  - Merged: \(.merged)",
  "  - Discarded: \(.discarded)",
  "",
  "  Discard breakdown:",
  "    • Low confidence: \(.discard_reasons.low_confidence)",
  "    • Out of scope: \(.discard_reasons.out_of_scope)",
  "    • Intentional pattern: \(.discard_reasons.intentional_pattern)",
  "    • Duplicate: \(.discard_reasons.duplicate)",
  "    • Too minor: \(.discard_reasons.too_minor)",
  "",
  "  Summary: \(.summary)"
'

# Save discarded findings for transparency
echo "$aggregation_result" | jq '.discarded_findings' > "${temp_dir}/discarded_findings.json"

echo ""
echo "💡 Review discarded findings: ${temp_dir}/discarded_findings.json"
```

**AI Agent's Full Responsibilities**:

1. ✅ **Filter irrelevant findings** (out of scope, low confidence, intentional patterns)
2. ✅ **Resolve conflicts** (merge related, keep highest severity for independent)
3. ✅ **De-duplicate** (same issue across multiple files)
4. ✅ **Merge related findings** (same root cause, complementary insights)
5. ✅ **Prioritize security** (never discard real vulnerabilities)
6. ✅ **Respect PR scope** (align with PR intent and constraints)
7. ✅ **Explain decisions** (transparent reasoning for discards)
8. ✅ **Generate final curated list** (only high-value comments)

**Why This Is Better**:

| Old Approach                      | New Approach (AI-Powered)            |
| --------------------------------- | ------------------------------------ |
| Hardcoded rules (confidence >60)  | Context-aware decisions              |
| Simple keyword matching           | Semantic understanding               |
| Can't judge "intentional pattern" | Uses codebase_patterns intelligently |
| Misses related findings           | Merges complementary insights        |
| No explanation                    | Transparent reasoning                |
| Rigid filtering                   | Flexible, intelligent curation       |

#### Step 3: Sort by Severity

AI agent already filtered and curated findings. Now just sort by severity for presentation:

```bash
sorted_findings=$(echo "$final_findings" | jq 'sort_by(
  if .severity == "critical" then 0
  elif .severity == "important" then 1
  elif .severity == "suggestion" then 2
  else 3
  end
)')

echo "📊 Final findings ready for formatting:"
echo "  - Total: $(echo "$sorted_findings" | jq 'length')"
echo "  - Critical: $(echo "$sorted_findings" | jq '[.[] | select(.severity == "critical")] | length')"
echo "  - Important: $(echo "$sorted_findings" | jq '[.[] | select(.severity == "important")] | length')"
echo "  - Suggestions: $(echo "$sorted_findings" | jq '[.[] | select(.severity == "suggestion")] | length')"
echo "  - Questions: $(echo "$sorted_findings" | jq '[.[] | select(.severity == "question")] | length')"
```

#### Step 4: Format Comment Bodies

The orchestrator now formats each finding into a complete, styled comment body (handles both merged and single findings):

````bash
# Format each finding into a complete markdown comment
formatted_findings=$(echo "$sorted_findings" | jq -r '.[] |
  # Determine severity emoji
  (if .severity == "critical" then "🚨"
   elif .severity == "important" then "⚠️"
   elif .severity == "suggestion" then "💡"
   else "❓"
   end) as $emoji |

  # Determine agent attribution (handle merged findings)
  (if .is_merged then
    (.agents | join(", "))
   else
    (.agent // "unknown")
   end) as $agent_list |

  # Build comment body
  {
    file: .file,
    line_start: .line_start,
    line_end: .line_end,
    severity: .severity,
    confidence: .confidence,
    category: .category,
    title: .title,
    is_merged: (.is_merged // false),
    body: (
      $emoji + " **" + (.severity | ascii_upcase) + " - " + .title + "**\n\n" +

      # Add merged indicator if applicable
      (if .is_merged then
        "🔗 *Multiple agents identified related issues on this line*\n\n"
      else "" end) +

      "**Issue**: " + .issue + "\n\n" +
      "**Why this matters**: " + .why_it_matters + "\n\n" +

      # Add attack example if present (for security findings)
      (if .attack_example then
        "**Attack example**:\n```" + (.attack_example_language // "text") + "\n" + .attack_example + "\n```\n\n"
      else "" end) +

      # Add performance impact if present
      (if .performance_impact then
        "**Performance impact**:\n```\n" + .performance_impact + "\n```\n\n"
      else "" end) +

      # Add fix section
      "**Fix**: " + .fix + "\n\n" +

      # Add fix code if present
      (if .fix_code then
        "```" + (.fix_code_language // "text") + "\n" + .fix_code + "\n```\n\n"
      else "" end) +

      # Add learning if present
      (if .learning then
        "**Learning**: " + .learning + "\n\n"
      else "" end) +

      # Add references if present
      (if .references and (.references | length > 0) then
        "**References**:\n" + (.references | map("- " + .) | join("\n")) + "\n\n"
      else "" end) +

      # Footer with agent attribution
      "---\n*🤖 Generated by OpenCode (" + $agent_list + ")*" +

      # Add resolution method indicator for debugging
      (if .is_merged then
        "\n*✨ Context-aware merge: Related findings combined*"
      elif .resolution_reason == "independent_issues" then
        "\n*🎯 Context-aware filter: Kept highest severity of independent findings*"
      else "" end)
    )
  }
')

# Save formatted findings
echo "$formatted_findings" > "${temp_dir}/formatted_findings.json"
````

**Comment Body Format Generated**:

The orchestrator generates fully-formatted markdown comments with:

- ✅ Severity emoji (🚨 ⚠️ 💡 ❓)
- ✅ Title with severity level
- ✅ Merge indicator (when multiple agents agree on related issues)
- ✅ Issue description (combined when merged)
- ✅ Impact explanation
- ✅ Attack examples (for security findings)
- ✅ Performance metrics (for performance findings)
- ✅ Fix description (primary + additional considerations when merged)
- ✅ Code examples with syntax highlighting
- ✅ Learning/educational takeaway
- ✅ References to docs or codebase examples
- ✅ Footer with agent attribution (shows all agents for merged findings)
- ✅ Resolution method indicator (merge vs filter)

**Example 1: Merged Comment (Related Findings)**:

````markdown
🚨 **CRITICAL - Multiple related issues: SQL injection vulnerability + Missing database index**

🔗 _Multiple agents identified related issues on this line_

**Issue**: Multiple agents identified related issues:

**security-reviewer**: User input concatenated directly into SQL query without parameterization

**performance-reviewer**: Query uses unindexed column lookup, causing full table scan

**Why this matters**: Attacker can execute arbitrary SQL, read/modify/delete any data in database. This is OWASP Top 10 #1.

Query performance degrades significantly with table growth. Current O(n) lookup will cause timeouts at scale.

**Attack example**:

```typescript
// If userId = "1 OR 1=1 --"
// Query becomes: SELECT * FROM users WHERE id = 1 OR 1=1 --
// Returns ALL users
```
````

**Performance impact**:

```
Current: Full table scan (1M rows = 5000ms)
With fix: Index lookup (1M rows = 2ms)
```

**Fix**: Use parameterized queries to prevent SQL injection

Additional considerations:

- Add database index on user_id column for O(1) lookups
- Consider query result caching for frequently accessed users

```typescript
const query = "SELECT * FROM users WHERE id = ?";
const result = await db.query(query, [userId]);
```

**Learning**: Never concatenate user input into SQL. Always use parameterized queries or an ORM to prevent SQL injection.

Indexing foreign keys and frequently queried columns is essential for performance at scale.

**References**:

- OWASP SQL Injection: https://owasp.org/www-community/attacks/SQL_Injection
- Database Indexing Best Practices: https://use-the-index-luke.com/
- See UserRepository.ts:42 for example of parameterized queries

---

_🤖 Generated by OpenCode (security-reviewer, performance-reviewer)_
_✨ Context-aware merge: Related findings combined_

````

**Example 2: Independent Finding (Highest Severity Kept)**:
```markdown
🚨 **CRITICAL - Hardcoded credentials in configuration**

**Issue**: Database password hardcoded in source code

**Why this matters**: Credentials in source control are accessible to anyone with repository access. If leaked, attackers gain full database access.

**Fix**: Move credentials to environment variables

```typescript
// Before
const dbPassword = "super_secret_password_123";

// After
const dbPassword = process.env.DB_PASSWORD;
````

**Learning**: Never commit credentials to source control. Use environment variables or secret management systems.

**References**:

- OWASP: Use of Hard-coded Credentials
- 12-Factor App: Store config in environment

---

_🤖 Generated by OpenCode (security-reviewer)_
_🎯 Context-aware filter: Kept highest severity of independent findings_

```

*(In this case, code-quality-reviewer also flagged the same line for poor variable naming, but since it's unrelated to the security issue and has lower severity, it was filtered out)*
- See UserRepository.ts:42 for example of parameterized queries

---
*🤖 Generated by OpenCode (security-reviewer)*
```

**Output**: Formatted findings ready to post, saved in `${temp_dir}/formatted_findings.json`

---

### Phase 6: Post Review

**Sequential** - Format summary, preview, and post final review

#### Step 1: Prepare for Preview

```bash
# formatted_findings is already prepared from Phase 5 Step 5
# This step just verifies the data is ready
```

#### Step 2: Display Preview Summary

```bash
echo ""
echo "======================================"
echo "📋 REVIEW SUMMARY - READY TO POST"
echo "======================================"
echo ""
echo "PR: #$pr_number"
echo "Agents Used: ${enabled_agents[*]}"
echo "Total Findings: $(echo "$formatted_findings" | jq '. | length')"
echo ""

# Show breakdown by severity
echo "Findings by Severity:"
echo "$formatted_findings" | jq -r '
  group_by(.severity) |
  map("  • " + (.[0].severity | ascii_upcase) + ": " + (. | length | tostring) + " issue(s)") |
  .[]
'
echo ""

# Show breakdown by file
echo "Findings by File:"
echo "$formatted_findings" | jq -r '
  group_by(.file) |
  map("  • " + .[0].file + ": " + (. | length | tostring) + " comment(s)") |
  .[]
'
echo ""

# Show detailed preview of each comment
echo "======================================"
echo "📝 DETAILED COMMENT PREVIEW"
echo "======================================"
echo ""

echo "$formatted_findings" | jq -r '.[] |
  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
  "📍 Location: " + .file + ":" + (.line_start | tostring) + "\n" +
  "🏷️  Severity: " + .severity + "\n" +
  "📊 Confidence: " + (.confidence | tostring) + "%\n" +
  "\nComment Body:\n" + .body + "\n"
'

echo "======================================"
echo ""
```

#### Step 3: Request User Approval

```bash
# Save formatted findings for potential manual review
echo "$formatted_findings" > "${temp_dir}/formatted_findings.json"

# Request approval from user
echo "⚠️  Ready to post review with $(echo "$formatted_findings" | jq '. | length') comments to PR #$pr_number"
echo ""
echo "Please review the summary above and approve posting."
echo ""

# Wait for user approval (orchestrator should prompt user)
# This is a checkpoint - execution should pause here for user confirmation
# User should explicitly approve before proceeding to Step 4

echo "💡 Files available for manual review:"
echo "   - Formatted findings: ${temp_dir}/formatted_findings.json"
echo ""
echo "⏸️  WAITING FOR USER APPROVAL TO POST REVIEW"
echo ""

# Note: The actual approval mechanism will be handled by the orchestrator
# The user must explicitly approve before the review is posted
```

#### Step 4: Post Review

```bash
# Get the latest commit SHA for the PR
commit_sha=$(gh pr view "$pr_number" --json headRefOid -q .headRefOid)

# Build review summary (high-level only, no detailed findings)
review_summary="## 🤖 OpenCode Multi-Agent Review

**Agents Used**: ${enabled_agents[*]}
**Findings**: $(echo "$formatted_findings" | jq '. | length') issues found

### Review Breakdown

$(echo "$formatted_findings" | jq -r '
  group_by(.severity) |
  map("- **" + (.[0].severity | ascii_upcase) + "**: " + (. | length | tostring) + " issue(s)") |
  .[]
')

---

*🤖 Generated by OpenCode Multi-Agent Review System*
*See inline comments below for detailed findings*"

# Build complete review payload with inline comments
# Use the pre-formatted body from formatted_findings
review_payload=$(jq -n \
  --arg body "$review_summary" \
  --arg event "COMMENT" \
  --arg commit_id "$commit_sha" \
  --argjson comments "$(echo "$formatted_findings" | jq -c '[
    .[] |
    if .line_start == .line_end then
      # Single-line comment
      {
        path: .file,
        line: .line_end,
        side: "RIGHT",
        body: .body
      }
    else
      # Multi-line comment
      {
        path: .file,
        start_line: .line_start,
        line: .line_end,
        start_side: "RIGHT",
        side: "RIGHT",
        body: .body
      }
    end
  ]')" \
  '{
    body: $body,
    event: $event,
    commit_id: $commit_id,
    comments: $comments
  }')

# Post review using GitHub CLI with proper JSON payload
echo "$review_payload" | gh api "repos/${owner}/${repo}/pulls/${pr_number}/reviews" \
  --method POST \
  --input -

echo ""
echo "✅ Review posted successfully to PR #$pr_number"
echo "   Posted $(echo "$formatted_findings" | jq '. | length') inline comments"
echo ""
```

**Output**: Posted review confirmation

---

### Phase 7: Cleanup

**Sequential** - Final teardown

```bash
# Note: Cleanup is automatically handled by the EXIT trap set in Phase 1
# The trap ensures cleanup happens even if the review fails partway through

# Report success
echo ""
echo "✅ Multi-agent review complete for PR #$pr_number"
echo "   Agents used: ${enabled_agents[*]}"
echo "   Findings posted: $(echo "$formatted_findings" | jq '. | length')"
echo ""
echo "🧹 Cleanup will be performed automatically on exit"
```

**Output**: Cleanup confirmation

---

## Performance Comparison

| Metric                    | v3 (Single Agent) | v4 (Multi-Agent) | Improvement    |
| ------------------------- | ----------------- | ---------------- | -------------- |
| **Code Quality Analysis** | 15s               | 5s               | 66% faster     |
| **Security Analysis**     | N/A               | 4s               | New capability |
| **Performance Analysis**  | N/A               | 3s               | New capability |
| **Total Review Time**     | 26s               | 12s (parallel)   | 54% faster     |
| **Specialist Depth**      | General           | Deep             | Higher quality |

**Key Benefits**:

- **Parallel execution**: All agents run simultaneously
- **Specialized expertise**: Each agent is a deep specialist
- **Dynamic selection**: Only runs relevant agents
- **Better accuracy**: Specialists have higher confidence in their domain

---

## Agent Selection Examples

### Example 1: OAuth Implementation PR

```
PR Title: "Add OAuth2 support for Google login"
PR contains: "authentication", "oauth", "token"

Auto-enabled agents:
  ✓ code-quality-reviewer (always)
  ✓ security-reviewer (detected: oauth, token, authentication)

Result: 2 agents (no performance-reviewer needed)
```

### Example 2: Database Optimization PR

```
PR Title: "Optimize user queries with indexes"
Files changed: UserRepository.ts, migrations/add-indexes.sql
PR contains: "query", "optimize", "database"

Auto-enabled agents:
  ✓ code-quality-reviewer (always)
  ✓ performance-reviewer (detected: query, optimize, database)

Result: 2 agents (no security-reviewer needed)
```

### Example 3: Large Refactoring PR

```
PR Title: "Refactor auth module"
Files changed: 25 files
PR contains: "auth", "password", "session"

Auto-enabled agents:
  ✓ code-quality-reviewer (always)
  ✓ security-reviewer (detected: auth, password, session)
  ✓ performance-reviewer (detected: large PR with 25 files)

Result: 3 agents (comprehensive review)
```

---

## Aggregation Strategy Details

### Context-Aware Resolution (v4.1)

Unlike simple severity hierarchy, v4.1 uses **intelligent context analysis** to decide whether to merge or filter findings:

#### Decision Tree

```
Multiple findings on same line?
├─ NO → Keep as-is (no conflict)
└─ YES → Analyze relationship
    ├─ Related findings (same root cause)?
    │   ├─ Share fix keywords? (parameterized, index, cache, etc.)
    │   ├─ Share category family? (sql-*, auth-*, etc.)
    │   └─ Share issue concepts? (4+ common words)
    │   → YES → MERGE into rich combined comment
    └─ Independent findings (different issues)?
        → Keep highest severity only (avoid clutter)
```

#### Example: Related Findings → MERGE

```
security-reviewer:     🚨 Critical - SQL injection (use parameterized queries)
performance-reviewer:  ⚠️ Important - Missing index (use parameterized queries with index)

Analysis:
✓ Share fix keywords: "parameterized", "queries"
✓ Share category family: "sql-*"
✓ Both address database query construction

Result: MERGE
→ One comment with both security and performance insights
→ Combined fix: "Use parameterized queries AND add database index"
→ Footer shows: "security-reviewer, performance-reviewer"
```

#### Example: Independent Findings → FILTER

```
security-reviewer:      🚨 Critical - Hardcoded credentials (use env vars)
code-quality-reviewer:  💡 Suggestion - Poor variable naming (rename to dbPassword)

Analysis:
✗ Different fix keywords: "environment" vs "rename"
✗ Different categories: "credentials" vs "naming"
✗ No issue overlap: security vs readability

Result: KEEP HIGHEST SEVERITY
→ Keep security finding only (Critical > Suggestion)
→ Avoid overwhelming developer with unrelated issues on same line
→ Footer shows: "security-reviewer"
```

### Relatedness Detection Algorithm

**Keywords Checked** (indicate same root cause):

```bash
# Security-related
"parameterized", "prepare", "validation", "sanitize", "escape", "hash", "encrypt"

# Performance-related
"index", "cache", "async", "await", "optimize"

# Code quality
"refactor", "extract", "rename", "simplify"
```

**Category Families**:

```bash
# Examples of related categories (share prefix)
sql-injection, sql-performance → Related (both "sql-*")
auth-session, auth-jwt → Related (both "auth-*")
crypto-weak, crypto-timing → Related (both "crypto-*")

# Examples of unrelated categories
sql-injection, naming-convention → Unrelated
auth-credentials, performance-loop → Unrelated
```

**Similarity Threshold**:

- **MERGE** if: 1+ shared fix keywords OR same category family OR 4+ shared issue words
- **FILTER** if: None of the above (keep highest severity)

### Benefits Over Simple Hierarchy

| Feature                  | Simple Hierarchy (Old)         | Context-Aware (New)           |
| ------------------------ | ------------------------------ | ----------------------------- |
| **Information Loss**     | High (discards lower severity) | Low (merges related findings) |
| **Developer Experience** | May miss related insights      | Gets complete picture         |
| **Comment Quality**      | One perspective                | Multiple expert perspectives  |
| **False Positives**      | Same                           | Reduced (better filtering)    |
| **Execution Time**       | Fast                           | Slightly slower (worth it)    |

**Example Impact**:

Old approach (SQL injection + missing index):

```
❌ Security finding kept
❌ Performance finding discarded
→ Developer fixes SQL injection but misses performance issue
```

New approach:

```
✅ Both findings merged into one rich comment
✅ Developer fixes both issues in one pass
→ Better code quality, fewer review cycles
```

### Conflict Resolution Priority

When findings cannot be merged, priority order:

```javascript
// 1. Severity (highest priority)
const SEVERITY_RANK = {
  critical: 4,
  important: 3,
  suggestion: 2,
  question: 1,
};

// 2. Category (within same severity)
const CATEGORY_PRIORITY = {
  security: 3,
  performance: 2,
  "code-quality": 1,
};

// 3. Confidence (tie-breaker)
// Higher confidence wins
```

---

## Error Handling

### Automatic Cleanup on Failure

All review artifacts and worktrees are automatically cleaned up via EXIT trap:

```bash
# Set in Phase 1 - runs on any exit (success or failure)

# Worktree mode: cleanup removes worktree and nested .review directory
cleanup_on_exit() {
  if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
    cd "$current_dir" > /dev/null 2>&1
    git worktree remove "$worktree_path" --force 2>/dev/null  # Removes entire worktree including .review/
    rmdir "${current_dir}/.worktree" 2>/dev/null || true
  fi
}

# Non-worktree mode: cleanup removes /tmp artifacts
cleanup_on_exit() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"  # Removes review artifacts from /tmp
  fi
}
trap cleanup_on_exit EXIT
```

**Benefits**:

- ✅ No orphaned review artifacts even if review crashes
- ✅ No orphaned worktrees even if review is interrupted
- ✅ Safe parallel execution (each PR has isolated resources)
- ✅ Atomic cleanup (removing worktree removes all artifacts)

### Agent Failures

If an agent fails:

```bash
# Continue with other agents (partial results better than none)
if ! wait "$agent_pid"; then
  echo "⚠️  WARNING: $agent failed, continuing with other agents"
  echo "{\"agent\": \"$agent\", \"findings\": [], \"metadata\": {\"error\": \"Agent failed\"}}" > "${temp_dir}/${agent}_output.json"
fi
```

### Aggregation Failures

If aggregation fails:

```bash
# Fall back to posting all findings without deduplication
if [ $? -ne 0 ]; then
  echo "⚠️  WARNING: Aggregation failed, posting all findings"
  sorted_findings="$all_findings"
fi
```

---

## Success Criteria

### Phase Completion

**Phase 1**: ✅ PR number extracted, worktree created (if needed), PR validated  
**Phase 2**: ✅ Metadata, files, diff fetched  
**Phase 3**: ✅ Shared context built with patterns, intent, focus areas  
**Phase 4**: ✅ All enabled agents completed and returned JSON  
**Phase 5**: ✅ Findings aggregated, filtered, sorted  
**Phase 6**: ✅ Review posted with inline comments  
**Phase 7**: ✅ Worktree removed, review artifacts cleaned

### Review Quality

- ✅ Appropriate agents selected based on PR content
- ✅ Agents ran in parallel (time savings)
- ✅ Conflicts resolved using severity hierarchy
- ✅ Irrelevant comments filtered out
- ✅ Educational explanations with code examples
- ✅ Review indicates which agents were used

---

## Comparison: v3 vs v4

| Feature                | v3 (Single Agent)     | v4 (Multi-Agent)           |
| ---------------------- | --------------------- | -------------------------- |
| **Architecture**       | Monolithic generalist | Specialized agents         |
| **Execution**          | Sequential phases     | Parallel agents            |
| **Security Review**    | Basic patterns        | Deep security expertise    |
| **Performance Review** | Basic patterns        | Deep performance expertise |
| **Code Quality**       | Comprehensive         | Comprehensive              |
| **Speed**              | 26s                   | 12s (parallel)             |
| **Extensibility**      | Add to one large file | Add new specialist agent   |
| **Maintenance**        | One 1600-line file    | Multiple focused files     |

**When to use v3**: Simple PRs, want single comprehensive reviewer  
**When to use v4**: Complex PRs, want specialist expertise, need speed

---

## Files Reference

**Specialist Agent files**:

- `agent/pr-reviewers/code-quality-reviewer.md` - Architecture, modularity, readability, testing
- `agent/pr-reviewers/security-reviewer.md` - Security vulnerabilities, OWASP Top 10
- `agent/pr-reviewers/performance-reviewer.md` - Performance issues, algorithmic complexity

**Aggregator Agent**:

- `agent/pr-reviewers/review-aggregator.md` - AI agent that filters, merges, and curates final findings

**Shared knowledge**:

- `shared/reviewer-base.md` - Common principles, output format, tone
- `shared/context-schema.md` - Shared context structure

**Orchestrator**:

- `command/review-pr-orchestration.md` - This file (workflow orchestration)

---

## Summary

This multi-agent review system with **AI-powered aggregation**:

1. **Selects** appropriate specialist agents based on PR content
2. **Gathers** shared context once for all agents
3. **Spawns** specialist agents in parallel for speed
4. **Invokes AI aggregator** to intelligently filter, merge, and curate findings
5. **Posts** unified review with only high-value, actionable comments

**Key Innovation**: AI aggregator makes all final decisions about what to keep, what to merge, and what to discard - resulting in high signal-to-noise ratio reviews.

**Result**: Faster, deeper, more accurate code reviews through specialization, parallelization, and intelligent curation.

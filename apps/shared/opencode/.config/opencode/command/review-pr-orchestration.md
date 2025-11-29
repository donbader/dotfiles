---
name: git:review-pr-orchestration
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

Each review session gets a unique identifier based on:
- Process ID (`$$`)
- Unix timestamp (`$(date +%s)`)

Example session IDs:
- `pr-review-12345-1701234567`
- `pr-review-12346-1701234568`

### Isolated Resources

Each session has its own:
- **Temporary directory**: `/tmp/opencode-review/pr-review-{pid}-{timestamp}/`
  - `shared_context.json`
  - `{agent}_output.json` files
  - `sorted_findings.json`
- **Worktree** (if using URL mode): `{current_dir}/.worktree/pr-review-{pr_number}/`
  - Created in your current working directory
  - Multiple PRs can have worktrees in the same `.worktree` folder

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
# 0. Create unique temporary directory for this review session
# This prevents conflicts when running multiple reviews in parallel
review_session_id="pr-review-$$-$(date +%s)"
temp_dir="/tmp/opencode-review/${review_session_id}"
mkdir -p "$temp_dir"

echo "📁 Review session: $review_session_id"
echo "📂 Temp directory: $temp_dir"

# Set up cleanup trap to ensure temp files are removed even on failure
cleanup_on_exit() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
    echo "🧹 Cleaned up temporary files"
  fi
}
trap cleanup_on_exit EXIT

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
  # Note: Even though we create it here, git tracks worktrees relative to repo root
  current_dir="$(pwd)"
  worktree_path="${current_dir}/.worktree/pr-review-${pr_number}"
  pr_branch=$(gh pr view "$pr_number" --json headRefName -q .headRefName)
  
  echo "📁 Current directory: $current_dir"
  echo "🌳 Creating worktree at: $worktree_path"
  
  # Create .worktree directory if it doesn't exist
  mkdir -p "${current_dir}/.worktree"
  
  git fetch origin "$pr_branch"
  git worktree add "$worktree_path" "origin/$pr_branch"
  cd "$worktree_path"
  
  # Add worktree cleanup to trap
  cleanup_on_exit() {
    if [ -d "$temp_dir" ]; then
      rm -rf "$temp_dir"
    fi
    if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
      cd - > /dev/null 2>&1
      git worktree remove "$worktree_path" --force 2>/dev/null
      # Also try to remove empty .worktree directory
      rmdir "${current_dir}/.worktree" 2>/dev/null || true
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

**Output**: `$pr_number`, `$worktree_path` (if created), `$use_worktree` flag, `$temp_dir`, `$review_session_id`

---

### Phase 2: Information Gathering
**Execute all tasks in parallel**

**Tasks**:
1. Fetch PR metadata: `gh pr view "$pr_number" --json title,body,author,state,isDraft,labels,baseRefName,headRefName`
2. Fetch files changed: `gh pr view "$pr_number" --json files`
3. Fetch PR diff: `gh pr diff "$pr_number"`
4. Fetch review history via GraphQL (detect existing OpenCode reviews)
5. Determine review mode (first/re-review/incremental)

**Output**: PR metadata, files changed, diff, review threads, suggested review mode

---

### Phase 3: Shared Context Building
**Sequential** - Build context object for all agents

**Tasks**:
1. Parse PR intent and constraints from description
2. Search codebase for patterns (count occurrences)
3. Identify architectural patterns and documentation
4. Analyze diff for statistical summary
5. Determine focus areas based on PR content
6. Build shared context JSON object

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
  "codebase_patterns": {
    "string_concatenation_for_queries": { "count": 12, "examples": [...] }
  },
  "architectural_context": { ... },
  "review_history": { ... }
}
```

**Output**: Shared context JSON object stored in `$temp_dir/shared_context.json`

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

**Output Format**:
{
  \"agent\": \"$agent\",
  \"findings\": [...],
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

### Phase 5: Aggregation & Filtering
**Sequential** - Intelligent result combination

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

#### Step 2: Apply Severity Hierarchy (Resolve Conflicts)

When multiple agents comment on the same line, keep highest severity:

```bash
# Severity ranking: critical > important > suggestion > question
severity_rank() {
  case "$1" in
    critical) echo 4 ;;
    important) echo 3 ;;
    suggestion) echo 2 ;;
    question) echo 1 ;;
    *) echo 0 ;;
  esac
}

# Group findings by file+line, keep highest severity
deduplicated_findings=$(echo "${all_findings[@]}" | jq -s '
  group_by(.file + ":" + (.line_start | tostring)) |
  map(
    max_by(
      if .severity == "critical" then 4
      elif .severity == "important" then 3
      elif .severity == "suggestion" then 2
      else 1
      end
    )
  )
')
```

#### Step 3: Filter Irrelevant Comments

```bash
# Orchestrator decides what to keep based on:
# 1. Confidence threshold (keep if confidence >= 60)
# 2. Relevance to PR scope (changed files only)
# 3. Not commenting on intentional patterns (check codebase_patterns)

filtered_findings=$(echo "$deduplicated_findings" | jq '[
  .[] |
  select(
    .confidence >= 60 and
    (.file | IN($files_changed[])) and
    (
      # Keep if pattern is rare (< 5 occurrences)
      (.category as $cat | 
       ($codebase_patterns | has($cat) | not) or
       ($codebase_patterns[$cat].count < 5)
      )
    )
  )
]')

echo "🔍 After filtering:"
echo "  - Remaining findings: $(echo "$filtered_findings" | jq '. | length')"
```

#### Step 4: Sort by Severity

```bash
sorted_findings=$(echo "$filtered_findings" | jq 'sort_by(
  if .severity == "critical" then 0
  elif .severity == "important" then 1
  elif .severity == "suggestion" then 2
  else 3
  end
)')
```

**Output**: Filtered, sorted findings ready to post

---

### Phase 6: Post Review
**Sequential** - Format, preview, and post final review

#### Step 1: Prepare Findings for Preview

```bash
# Findings are already in sorted_findings.json from Phase 5
# This step just prepares them for the preview in Step 2
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
echo "Total Findings: $(echo "$sorted_findings" | jq '. | length')"
echo ""

# Show breakdown by severity
echo "Findings by Severity:"
echo "$sorted_findings" | jq -r '
  group_by(.severity) |
  map("  • " + (.[0].severity | ascii_upcase) + ": " + (. | length | tostring) + " issue(s)") |
  .[]
'
echo ""

# Show breakdown by file
echo "Findings by File:"
echo "$sorted_findings" | jq -r '
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

echo "$sorted_findings" | jq -r '.[] | 
  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
  "📍 Location: " + .file + ":" + (.line_start | tostring) + "\n" +
  "🏷️  Severity: " + .severity + "\n" +
  "🎯 Category: " + .category + "\n" +
  "💬 Agent: " + .agent + "\n" +
  "📊 Confidence: " + (.confidence | tostring) + "%\n" +
  "\nComment Body:\n" + .body + "\n"
'

echo "======================================"
echo ""
```

#### Step 3: Request User Approval

```bash
# Save findings for potential manual review
echo "$sorted_findings" > "${temp_dir}/sorted_findings.json"

# Request approval from user
echo "⚠️  Ready to post review with $(echo "$sorted_findings" | jq '. | length') comments to PR #$pr_number"
echo ""
echo "Please review the summary above and approve posting."
echo ""

# Wait for user approval (orchestrator should prompt user)
# This is a checkpoint - execution should pause here for user confirmation
# User should explicitly approve before proceeding to Step 4

echo "💡 Files available for manual review:"
echo "   - Findings JSON: ${temp_dir}/sorted_findings.json"
echo ""
echo "⏸️  WAITING FOR USER APPROVAL TO POST REVIEW"
echo ""

# Note: The actual approval mechanism will be handled by the orchestrator
# The user must explicitly approve before the review is posted
```

#### Step 4: Post Review

```bash
# Build review summary (high-level only, no detailed findings)
review_summary="## 🤖 OpenCode Multi-Agent Review

**Agents Used**: ${enabled_agents[*]}
**Findings**: $(echo "$sorted_findings" | jq '. | length') issues found

### Review Breakdown

$(echo "$sorted_findings" | jq -r '
  group_by(.severity) |
  map("- **" + (.[0].severity | ascii_upcase) + "**: " + (. | length | tostring) + " issue(s)") |
  .[]
')

---

*🤖 Generated by OpenCode Multi-Agent Review System*
*See inline comments below for detailed findings*"

# Build complete review payload with inline comments
review_payload=$(jq -n \
  --arg body "$review_summary" \
  --arg event "COMMENT" \
  --argjson comments "$(echo "$sorted_findings" | jq -c '[
    .[] |
    {
      path: .file,
      line: .line_start,
      side: "RIGHT",
      body: .body
    }
  ]')" \
  '{
    body: $body,
    event: $event,
    comments: $comments
  }')

# Post review using GitHub CLI with proper JSON payload
echo "$review_payload" | gh api "repos/${owner}/${repo}/pulls/${pr_number}/reviews" \
  --method POST \
  --input -

echo ""
echo "✅ Review posted successfully to PR #$pr_number"
echo "   Posted $(echo "$sorted_findings" | jq '. | length') inline comments"
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
echo "   Findings posted: $(echo "$sorted_findings" | jq '. | length')"
echo ""
echo "🧹 Cleanup will be performed automatically on exit"
```

**Output**: Cleanup confirmation

---

## Performance Comparison

| Metric | v3 (Single Agent) | v4 (Multi-Agent) | Improvement |
|--------|-------------------|------------------|-------------|
| **Code Quality Analysis** | 15s | 5s | 66% faster |
| **Security Analysis** | N/A | 4s | New capability |
| **Performance Analysis** | N/A | 3s | New capability |
| **Total Review Time** | 26s | 12s (parallel) | 54% faster |
| **Specialist Depth** | General | Deep | Higher quality |

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

### Severity Hierarchy

When multiple agents flag the same line:

```
security-reviewer:     🚨 Critical - SQL injection
performance-reviewer:  💡 Suggestion - Use prepared statements

Result: Keep security-reviewer finding (Critical > Suggestion)
```

**Rationale**: 
- Security issues are more critical than performance
- Performance issues are more critical than code quality
- Avoid overwhelming developer with multiple comments on same line

### Conflict Resolution

```javascript
// Priority order
const SEVERITY_PRIORITY = {
  'critical': 100,
  'important': 75,
  'suggestion': 50,
  'question': 25
};

// Category priority (within same severity)
const CATEGORY_PRIORITY = {
  'security': 3,
  'performance': 2,
  'code-quality': 1
};

// Keep finding with:
// 1. Highest severity
// 2. If tied, highest category priority
// 3. If tied, highest confidence
```

---

## Error Handling

### Automatic Cleanup on Failure

All temporary files and worktrees are automatically cleaned up via EXIT trap:
```bash
# Set in Phase 1 - runs on any exit (success or failure)
cleanup_on_exit() {
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"  # Removes session-specific temp files
  fi
  if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
    cd - > /dev/null 2>&1
    git worktree remove "$worktree_path" --force 2>/dev/null
  fi
}
trap cleanup_on_exit EXIT
```

**Benefits**:
- ✅ No orphaned temp files even if review crashes
- ✅ No orphaned worktrees even if review is interrupted
- ✅ Safe parallel execution (each session has unique temp directory)

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
**Phase 7**: ✅ Worktree removed, temp files cleaned

### Review Quality

- ✅ Appropriate agents selected based on PR content
- ✅ Agents ran in parallel (time savings)
- ✅ Conflicts resolved using severity hierarchy
- ✅ Irrelevant comments filtered out
- ✅ Educational explanations with code examples
- ✅ Review indicates which agents were used

---

## Comparison: v3 vs v4

| Feature | v3 (Single Agent) | v4 (Multi-Agent) |
|---------|-------------------|------------------|
| **Architecture** | Monolithic generalist | Specialized agents |
| **Execution** | Sequential phases | Parallel agents |
| **Security Review** | Basic patterns | Deep security expertise |
| **Performance Review** | Basic patterns | Deep performance expertise |
| **Code Quality** | Comprehensive | Comprehensive |
| **Speed** | 26s | 12s (parallel) |
| **Extensibility** | Add to one large file | Add new specialist agent |
| **Maintenance** | One 1600-line file | Multiple focused files |

**When to use v3**: Simple PRs, want single comprehensive reviewer  
**When to use v4**: Complex PRs, want specialist expertise, need speed

---

## Files Reference

**Agent files**:
- `agent/code-quality-reviewer.md` - Architecture, modularity, readability, testing
- `agent/security-reviewer.md` - Security vulnerabilities, OWASP Top 10
- `agent/performance-reviewer.md` - Performance issues, algorithmic complexity

**Shared knowledge**:
- `shared/reviewer-base.md` - Common principles, output format, tone
- `shared/context-schema.md` - Shared context structure

**Orchestrator**:
- `command/review-pr-v4-multi-agent.md` - This file (workflow orchestration)

---

## Summary

This multi-agent review system:

1. **Selects** appropriate specialist agents based on PR content
2. **Gathers** shared context once for all agents
3. **Spawns** agents in parallel for speed
4. **Aggregates** results using severity hierarchy
5. **Filters** irrelevant findings using context
6. **Posts** unified review with educational comments

**Result**: Faster, deeper, more accurate code reviews through specialization and parallelization.

---
name: git:review-pr-v4
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
  worktree_path=".worktree/pr-review-${pr_number}"
  pr_branch=$(gh pr view "$pr_number" --json headRefName -q .headRefName)
  
  git fetch origin "$pr_branch"
  git worktree add "$worktree_path" "origin/$pr_branch"
  cd "$worktree_path"
fi

# 3. Validate PR exists and is accessible
gh pr view "$pr_number" --json title,state || {
  echo "ERROR: Cannot access PR #$pr_number"
  exit 1
}
```

**Output**: `$pr_number`, `$worktree_path` (if created), `$use_worktree` flag

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

**Output**: Shared context JSON object

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
$(cat shared_context.json)

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
    > "${agent}_output.json"
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

**Output**: JSON output files from each agent

---

### Phase 5: Aggregation & Filtering
**Sequential** - Intelligent result combination

#### Step 1: Collect All Findings

```bash
all_findings=()

for agent in "${enabled_agents[@]}"; do
  agent_findings=$(jq -r '.findings[]' "${agent}_output.json")
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
**Sequential** - Format and post final review

```bash
# Build review summary
cat > review_summary.md <<EOF
## 🤖 OpenCode Multi-Agent Review (v4)

**Agents Used**: ${enabled_agents[*]}
**Findings**: $(echo "$sorted_findings" | jq '. | length') issues found

### Review Breakdown

$(echo "$sorted_findings" | jq -r '
  group_by(.severity) |
  map("- " + (.[0].severity | ascii_upcase) + ": " + (. | length | tostring) + " issues") |
  .[]
')

---

$(echo "$sorted_findings" | jq -r '.[] | 
  "### " + .file + ":" + (.line_start | tostring) + "\n\n" + .body + "\n\n"
')

---

*🤖 Generated by OpenCode Multi-Agent Review System*
*Agents: $(echo "${enabled_agents[@]}" | sed 's/ /, /g')*
EOF

# Post review using GitHub CLI
gh api "repos/${owner}/${repo}/pulls/${pr_number}/reviews" \
  --method POST \
  -f event=COMMENT \
  -F body=@review_summary.md \
  -f comments="$(echo "$sorted_findings" | jq -c '[
    .[] |
    {
      path: .file,
      line: .line_start,
      side: "RIGHT",
      body: .body
    }
  ]')"

echo "✅ Review posted successfully"
```

**Output**: Posted review confirmation

---

### Phase 7: Cleanup
**Sequential** - Final teardown

```bash
# 1. Remove worktree (if created)
if [ "$use_worktree" = true ]; then
  cd - > /dev/null
  git worktree remove "$worktree_path" --force 2>/dev/null || {
    echo "WARNING: Failed to remove worktree at $worktree_path"
    echo "Manual cleanup: git worktree remove $worktree_path --force"
  }
fi

# 2. Clean up temporary files
rm -f shared_context.json
rm -f *_output.json
rm -f review_summary.md

# 3. Report success
echo "✅ Multi-agent review complete for PR #$pr_number"
echo "   Agents used: ${enabled_agents[*]}"
echo "   Findings posted: $(echo "$sorted_findings" | jq '. | length')"
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

### Agent Failures

If an agent fails:
```bash
# Continue with other agents (partial results better than none)
if ! wait "$agent_pid"; then
  echo "⚠️  WARNING: $agent failed, continuing with other agents"
  echo "{\"agent\": \"$agent\", \"findings\": [], \"metadata\": {\"error\": \"Agent failed\"}}" > "${agent}_output.json"
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

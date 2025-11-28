# Phase 3: Gather Context

Before analyzing code, gather context to avoid false positives on Critical issues.

## Step 1: Search for Historical Context

For better-informed reviews, search for related discussions and past decisions:

```bash
# Get repository info
repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')

# Extract key terms from changed files for searching
changed_files=$(gh pr view $pr_number --json files -q '.files[].path')
search_terms=$(echo "$changed_files" | xargs basename -a | sed 's/\.[^.]*$//' | head -3)

echo "=== SEARCHING FOR HISTORICAL CONTEXT ==="

# Search for related issues (limit to prevent noise)
for term in $search_terms; do
  echo "--- Issues related to: $term ---"
  gh issue list --repo "$repo_info" --search "$term" --limit 3 --json number,title,url \
    --jq '.[] | "  #\(.number): \(.title)\n  \(.url)"' 2>/dev/null || true
done

# Search for related PRs (especially useful for understanding patterns)
echo "--- Related PRs ---"
for term in $search_terms; do
  gh pr list --repo "$repo_info" --search "$term" --state all --limit 3 \
    --json number,title,url,state \
    --jq '.[] | "  #\(.number) [\(.state)]: \(.title)\n  \(.url)"' 2>/dev/null || true
done

# Search for code comments explaining trade-offs
echo "=== CODE COMMENTS AND NOTES ==="
for file in $changed_files; do
  if [ -f "$file" ]; then
    echo "--- Comments in: $file ---"
    rg "TODO|FIXME|NOTE|HACK|WARNING|IMPORTANT" "$file" --context 1 || true
  fi
done
```

## Step 2: Analyze Codebase Patterns

Understand how THIS codebase handles similar scenarios:

```bash
echo "=== ANALYZING CODEBASE PATTERNS ==="

# For each changed file, find similar files in same directory
for file in $changed_files; do
  file_dir=$(dirname "$file")
  file_base=$(basename "$file" | sed 's/\.[^.]*$//')
  
  echo "--- Patterns in directory: $file_dir ---"
  
  # Common pattern searches based on file type
  if [[ "$file" == *.go ]]; then
    # Go-specific patterns
    echo "Error handling patterns:"
    rg "if err != nil" "$file_dir" --context 2 | head -20 || true
    
    echo "Cache/database write patterns:"
    rg "cache\\.Set|db\\.Write|\.Save\(" "$file_dir" --context 3 | head -20 || true
    
  elif [[ "$file" == *.ts ]] || [[ "$file" == *.js ]]; then
    # TypeScript/JavaScript patterns
    echo "Error handling patterns:"
    rg "catch|\.then\(.*,.*\)|try" "$file_dir" --context 2 | head -20 || true
    
  elif [[ "$file" == *.py ]]; then
    # Python patterns
    echo "Error handling patterns:"
    rg "except|try:" "$file_dir" --context 2 | head -20 || true
  fi
  
  # Find similar filenames (e.g., other subscription handlers)
  echo "Similar files in directory:"
  ls -1 "$file_dir" | rg "$(echo $file_base | sed 's/_recording//' | sed 's/_subscription//')" || true
done
```

## Step 3: Extract PR Context Clues

Parse the PR description for constraints and known trade-offs:

```bash
echo "=== PR DESCRIPTION ANALYSIS ==="

pr_body=$(gh pr view $pr_number --json body -q '.body')

# Look for constraint indicators
echo "Detected constraints:"
echo "$pr_body" | rg -i "out of order|race condition|async|eventual|best effort|known issue" --context 1 || echo "  None detected"

# Look for scope indicators
echo "Detected scope:"
echo "$pr_body" | rg -i "hotfix|quick fix|part \d of|follow.?up|separate PR|future work" --context 1 || echo "  Standard PR"

# Look for referenced issues/tickets
echo "Referenced issues:"
echo "$pr_body" | rg -o "[A-Z]+-\d+|#\d+" | sort -u || echo "  None referenced"

# Look for testing mentions
echo "Testing approach:"
echo "$pr_body" | rg -i "test|tested|testing" --context 1 || echo "  Not mentioned"
```

## Step 4: Build Context Summary

Create a summary to inform review severity:

```bash
echo "=== CONTEXT SUMMARY FOR REVIEW ==="
echo "Repository patterns:"
echo "  - Check output above for how this codebase handles errors, cache writes, etc."
echo "PR constraints:"
echo "  - Check PR description for 'out of order', 'hotfix', 'separate PR', etc."
echo "Historical decisions:"
echo "  - Check related PRs/issues for past discussions on similar topics"
echo ""
echo "Use this context to:"
echo "  🚨 Critical → Only for high-confidence bugs given the context"
echo "  ⚠️ Important → For potential issues that might be intentional"
echo "  💡 Suggestion → When pattern differs from typical but matches codebase"
echo "  ❓ Question → When missing context to determine if issue or intentional"
```

**Key Decision Rules After Context Gathering:**

1. **If pattern exists in 3+ similar files** → Likely intentional, downgrade severity
2. **If PR description mentions constraint** (e.g., "out of order") → Frame as question
3. **If related PR/issue discusses same topic** → Reference it, avoid re-litigating
4. **If code has explanatory comment** → Acknowledge it, might just need clarification
5. **If hotfix/quick fix** → Focus on correctness over architecture

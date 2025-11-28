# Phase 5: Two-Pass Review Strategy

Use a two-pass approach to reduce false positives on critical issues.

## Pass 1: Pattern Detection (Automated Scan)

First, scan for high-risk patterns without context:

```bash
echo "=== PASS 1: PATTERN DETECTION ==="

# Define dangerous patterns to scan for
declare -A patterns=(
  # Security patterns
  ["sql_injection"]="SELECT.*FROM.*\+|query.*=.*\+.*WHERE|db\\.exec.*%s|string concatenation in SQL"
  ["xss"]="dangerouslySetInnerHTML|innerHTML.*=|eval\(|new Function\("
  ["auth_bypass"]="if.*==.*admin|auth.*=.*true|skip.*auth"
  
  # Correctness patterns
  ["state_without_error_check"]="if err != nil.*\n.*}\n.*state.*=|cache\\.Set.*err.*\n.*state\\.update"
  ["null_deref"]="\\[.*\\](?!.*if.*!=.*nil)|\\.(.*?)(?!.*if.*!=.*nil)"
  
  # Performance patterns  
  ["n_plus_one"]="for.*range.*\n.*db\\.Query|map.*=>.*fetch|loop.*SELECT"
  ["inefficient_loop"]="for.*for.*for"
)

# Scan changed files for patterns
pr_diff=$(gh pr diff $pr_number)
detected_patterns=()

for pattern_name in "${!patterns[@]}"; do
  pattern="${patterns[$pattern_name]}"
  
  if echo "$pr_diff" | rg -U "$pattern" > /dev/null 2>&1; then
    echo "⚠️  Detected pattern: $pattern_name"
    detected_patterns+=("$pattern_name")
    
    # Show where it was found
    echo "$pr_diff" | rg -U "$pattern" --context 3 | head -20
    echo ""
  fi
done

if [ ${#detected_patterns[@]} -eq 0 ]; then
  echo "✅ No high-risk patterns detected in Pass 1"
fi
```

## Pass 2: Context-Aware Analysis (For Each Detected Pattern)

For each pattern found, gather context before determining severity:

```bash
echo "=== PASS 2: CONTEXT-AWARE ANALYSIS ==="

for pattern_name in "${detected_patterns[@]}"; do
  echo "--- Analyzing: $pattern_name ---"
  
  # Step 1: Find the file and line where pattern was detected
  pattern="${patterns[$pattern_name]}"
  locations=$(echo "$pr_diff" | rg -n "$pattern" --only-matching | head -5)
  
  for location in $locations; do
    file=$(echo "$location" | cut -d: -f1)
    line=$(echo "$location" | cut -d: -f2)
    
    echo "Location: $file:$line"
    
    # Step 2: Read surrounding code (±50 lines for full context)
    echo "Code context:"
    if [ -f "$file" ]; then
      start_line=$((line - 20 > 0 ? line - 20 : 1))
      end_line=$((line + 20))
      sed -n "${start_line},${end_line}p" "$file" | cat -n
    fi
    
    # Step 3: Search for similar patterns in codebase
    echo "Checking if pattern exists elsewhere in codebase:"
    file_dir=$(dirname "$file")
    similar_count=$(rg "$pattern" "$file_dir" --count 2>/dev/null | wc -l | tr -d ' ')
    echo "  Found in $similar_count files in $file_dir"
    
    if [ "$similar_count" -gt 3 ]; then
      echo "  ⚠️  Pattern appears common in this codebase (${similar_count} files)"
      echo "  Consider: Might be intentional - downgrade to ⚠️ Important or 💡 Suggestion"
    fi
    
    # Step 4: Check for explanatory comments near the code
    echo "Checking for explanatory comments:"
    if [ -f "$file" ]; then
      start_line=$((line - 5 > 0 ? line - 5 : 1))
      end_line=$((line + 2))
      comments=$(sed -n "${start_line},${end_line}p" "$file" | rg "//.*NOTE|//.*TODO|//.*HACK|//.*WARNING" || echo "None")
      echo "  $comments"
      
      if [ "$comments" != "None" ]; then
        echo "  ⚠️  Author has commented on this - likely aware of trade-off"
        echo "  Consider: Frame as 💡 Suggestion to clarify comment, not 🚨 Critical"
      fi
    fi
    
    # Step 5: Check PR description for context
    echo "Checking PR description for relevant context:"
    pr_context=$(gh pr view $pr_number --json body -q '.body' | \
      rg -i "constraint|trade.?off|known|intentional|hotfix|temporary" --context 1 || echo "None")
    
    if [ "$pr_context" != "None" ]; then
      echo "  Found context in PR description:"
      echo "$pr_context" | head -5
      echo "  ⚠️  PR mentions constraints/trade-offs - pattern might be intentional"
    fi
    
    # Step 6: Decision matrix based on gathered context
    echo "Decision for $pattern_name at $file:$line:"
    
    # High confidence → Critical
    if [ "$pattern_name" = "sql_injection" ] && [ "$similar_count" -lt 2 ] && [ "$comments" = "None" ]; then
      echo "  → 🚨 CRITICAL: High-risk pattern, not common in codebase, no explanation"
      
    # Pattern exists in codebase → Important or Question
    elif [ "$similar_count" -gt 3 ]; then
      echo "  → ⚠️ IMPORTANT or 💡 SUGGESTION: Pattern common in codebase, might be standard"
      echo "     Frame as: 'I noticed this pattern in ${similar_count} files. Is this intentional because...?'"
      
    # Author has comment → Question
    elif [ "$comments" != "None" ]; then
      echo "  → 💡 SUGGESTION: Author aware (has comment), ask for clarification"
      echo "     Frame as: 'Could you clarify the comment at line X? Are you trading off Y for Z?'"
      
    # PR mentions trade-offs → Important with question
    elif [ "$pr_context" != "None" ]; then
      echo "  → ⚠️ IMPORTANT: PR mentions constraints, frame as question"
      echo "     Frame as: 'Given the constraint mentioned in PR description, is this pattern needed?'"
      
    # Medium confidence → Important
    else
      echo "  → ⚠️ IMPORTANT: Potential issue but missing full context"
      echo "     Frame as: 'Concern: ... However, I may be missing context: ...'"
    fi
    
    echo ""
  done
done
```

## Pass 2 Output Summary

After both passes, create a summary for the AI reviewer:

```bash
echo "=== REVIEW GUIDANCE FROM TWO-PASS ANALYSIS ==="
echo ""
echo "Patterns detected: ${#detected_patterns[@]}"
echo ""
echo "Severity recommendations based on context:"
echo "  🚨 Critical → Only if: high-risk pattern + not common + no explanation + no PR context"
echo "  ⚠️ Important → If: pattern exists elsewhere OR PR mentions constraints"  
echo "  💡 Suggestion → If: author has comment OR pattern very common (5+ files)"
echo "  ❓ Question → When: missing key context to determine severity"
echo ""
echo "Key findings to reference in review comments:"
for pattern_name in "${detected_patterns[@]}"; do
  echo "  - $pattern_name: [reference Pass 2 analysis above]"
done
```

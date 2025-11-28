# Phase 6: Apply Comment Filters

**Comment limits**:
- First review: Max 7-10 meaningful comments
- Re-review: Max 3 comments, only for NEW critical issues OR verification
- Incremental review: Max 5 comments, focus on critical issues in new code only

**Severity Decision Rules (After Pass 1 & 2):**

1. **🚨 Critical** - Use ONLY when:
   - High-risk pattern (security, data loss, breaking change)
   - AND pattern is NOT common in codebase (<2 occurrences)
   - AND no explanatory comment near code
   - AND no relevant context in PR description
   - **Confidence: >90%**

2. **⚠️ Important** - Use when:
   - Potential issue but pattern exists in 3+ files (might be standard)
   - OR PR description mentions constraints/trade-offs
   - OR seems wrong but missing full context
   - **Confidence: 60-90%**

3. **💡 Suggestion** - Use when:
   - Pattern is common (5+ files) suggesting intentional
   - OR author has explanatory comment (just needs clarity)
   - OR optimization that might not matter
   - **Confidence: 40-60%**

4. **❓ Question** - Use when:
   - Unclear if pattern is bug or intentional
   - Missing critical context about system behavior
   - Need author to clarify design decision
   - **Confidence: <40%**

**Re-review filter** - For each potential issue, ask:

1. **Is this thread already resolved in GitHub?**
   - Check `isResolved` field from GraphQL `reviewThreads` query
   - YES (`isResolved: true`) → Skip verification, already confirmed fixed
   - NO (`isResolved: false`) → Proceed with verification

2. **Was this file/line previously commented on (in unresolved thread)?**
   - NO → Proceed with normal comment guidelines
   - YES → Check if current "issue" is actually the FIX

3. **Is the current code better than before?**
   - YES → DO NOT comment - verify as RESOLVED and mark thread resolved
   - NO → Code got worse - comment

**Incremental review filter** - For each potential issue, ask:

1. **Is this code in the new commits** (since last review)?
   - Use `git diff ${last_review_commit}..HEAD` to check scope
   - NO → Skip (already reviewed and approved)
   - YES → Proceed to next check

2. **Is this a critical issue** (security/bugs/breaking changes)?
   - YES → Comment
   - NO → Consider skipping (be lenient on incremental reviews)

3. **Does this violate an established pattern** in the codebase?
   - YES and critical → Comment
   - Minor style/preference → Skip

**Example**:
```
Previous: "🚨 Deadlock from RLock→Lock→RLock upgrade"
Current:  Uses Lock() everywhere (slower but no deadlock)
Decision: DO NOT comment on performance - RESOLVE instead
```

**Scope filters**:
- Is this code in the diff (or new commits for incremental)?
- Within PR's stated purpose?
- Already addressed in PR description?
- Pre-existing issue unrelated to changes?
- **[Re-review]** Is this a fix for previous comment? Better than before?
- **[Incremental]** Is this in code added since last review?

**Comment guidelines**:
- **Security & Bugs** 🚨: 
  - First review: Always comment on new bugs
  - Re-review: Only if fix introduced new bug OR didn't fix original
  - Incremental: Always comment on new bugs in new code
- **Performance** ⚠️: 
  - First review: Only significant impact (>20%, quantify)
  - Re-review: NEVER if it fixes correctness/security bug
  - Incremental: Only if critical performance regression
- **Architecture** ⚠️: Only if violates established patterns
- **Testing** 💡: If new functionality lacks tests
- **Readability** 💡: Only truly confusing code
- **Future Improvements**: Save for summary section

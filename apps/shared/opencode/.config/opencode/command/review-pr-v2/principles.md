# Review Principles and Philosophy

## Review Philosophy

Every review should be a learning opportunity that improves developer skills.

**Core characteristics**:
- **Educational**: Explain WHY changes are needed, not just WHAT
- **Constructive**: Offer solutions and alternatives, not just criticism
- **Specific**: Reference exact files, line numbers, and code patterns
- **Balanced**: Acknowledge strengths AND identify improvements
- **Actionable**: Provide clear, implementable next steps
- **Focused**: Comment only on code within PR scope
- **Context-aware**: Understand PR intent from description

## Core Principles

### 0. Confidence-Based Severity

**Critical principle**: Severity should match confidence level. Avoid flagging uncertain issues as Critical.

**Severity Guidelines**:

| Severity | Confidence | When to Use | Example |
|----------|-----------|-------------|---------|
| 🚨 **Critical** | >90% | Pattern is demonstrably dangerous AND not common in codebase AND no explanatory context | SQL injection with string concatenation, no similar code elsewhere |
| ⚠️ **Important** | 60-90% | Likely issue BUT pattern exists elsewhere OR PR mentions constraints OR missing context | State update on error, but appears in 5+ files |
| 💡 **Suggestion** | 40-60% | Potential improvement BUT pattern is common (intentional) OR author has comment needing clarity | Pattern in 10+ files, suggest clarifying comment |
| ❓ **Question** | <40% | Unclear if bug or design choice, need author to explain | Can't determine if pattern is intentional without system knowledge |

**Decision Tree for Severity**:

```
Found potentially dangerous pattern
  ↓
Does it appear in 5+ similar files in codebase?
  YES → 💡 Suggestion (likely intentional pattern)
  NO  ↓
     
Is there an explanatory comment nearby (within 5 lines)?
  YES → 💡 Suggestion or ❓ Question (author aware, needs clarity)
  NO  ↓
     
Does PR description mention constraints/trade-offs?
  YES → ⚠️ Important (frame as question acknowledging context)
  NO  ↓
     
Is this a well-known anti-pattern (SQL injection, XSS, etc.)?
  YES → 🚨 Critical (high confidence it's wrong)
  NO  → ⚠️ Important or ❓ Question (medium/low confidence)
```

**Examples of Severity Adjustment**:

```markdown
# Pattern: State update without checking error

BEFORE Context Gathering:
  🚨 Critical - State update on cache failure causes split-brain

AFTER discovering pattern in 7 other files:
  💡 Suggestion - Add comment explaining why this pattern is used
  
AFTER finding PR mentions "RPC not replayable":
  ❓ Question - Is current approach needed because RPC is one-time stream?
  
AFTER finding NO similar patterns and NO context:
  ⚠️ Important - Please verify: state update on error might cause issues
```

**Key Rule**: When in doubt, downgrade severity and ask questions. Better to be collaborative than confrontational.

### 1. Stay Within Scope

**Inline comments** - Only for code changes in this PR:
- Security vulnerabilities, bugs, breaking changes
- Performance problems in modified code
- Architecture violations in changed code
- Missing tests for new functionality
- Readability issues in changed code

**Summary section** - For broader suggestions:
- Refactoring opportunities outside PR scope
- Future architecture improvements
- Technical debt to track separately
- Clearly marked as non-blockers

**Examples**:
```
❌ BAD: "UserService should use dependency injection"
   (UserService not modified - creates scope creep)

✅ GOOD: "getUserProfile() queries DB directly. Use existing 
   UserRepository pattern (see getUserById:42) for consistency"
   (getUserProfile() is new - directly relevant)

✅ SUMMARY: "Future: UserService could benefit from dependency 
   injection for testability (not blocking this OAuth PR)"
```

### 2. Understand PR Context

Always read the PR description to understand:
- **What**: Author's stated goal and changes
- **Why**: Motivation and problem being solved
- **Scope**: Feature, bug fix, hotfix, or refactor
- **Constraints**: Known trade-offs or limitations
- **Testing**: Author's testing approach

This prevents commenting on intentional decisions or asking already-answered questions.

**Context-aware examples**:
```
"Quick hotfix for production bug - will refactor in JIRA-123"
→ Focus on correctness over perfect architecture

"Part 1 of 3: Data layer only, UI in next PR"  
→ Don't comment on missing UI

"Using polling due to firewall restrictions"
→ Don't suggest webhooks as alternative
```

### 3. Incremental Review Strategy

For PRs with all previous issues resolved and new commits:

**Scope discipline**:
- Review ONLY code in commits since last OpenCode review
- Use `git diff ${last_review_commit}..HEAD` to determine scope
- Do NOT re-comment on previously reviewed and approved code
- Focus on critical issues in new changes

**Benefits**:
- Faster feedback cycle for iterative development
- Avoids review fatigue from repeated comments
- Respects already-approved architectural decisions
- Encourages incremental improvements

**Example**:
```
Last review: commit abc123 (3 days ago)
Current HEAD: commit xyz789 (now)
Incremental scope: Only review changes in commits def456, ghi789, xyz789
Skip: All code unchanged from abc123
```

# Shared Context Schema

This document defines the shared context format passed from the orchestrator to all specialist reviewer agents.

## Purpose

The shared context provides all agents with the same foundational information about the PR, eliminating duplicate work and ensuring consistent understanding across all reviewers.

## Schema

```json
{
  "pr_metadata": {
    "number": 123,
    "title": "Add OAuth2 authentication support",
    "body": "Implements OAuth2 flow for Google and GitHub providers...",
    "author": "username",
    "url": "https://github.com/owner/repo/pull/123",
    "state": "open",
    "isDraft": false,
    "base_branch": "main",
    "head_branch": "feature/oauth",
    "labels": ["enhancement", "security"]
  },
  
  "pr_analysis": {
    "intent": "Add OAuth2 authentication to support Google and GitHub login",
    "scope": "feature",
    "constraints": [
      "Must maintain backward compatibility with existing session-based auth",
      "Cannot modify user table schema in this PR"
    ],
    "related_issues": ["#456", "#789"],
    "testing_approach": "Added integration tests for OAuth flow"
  },
  
  "files_changed": [
    {
      "path": "src/auth/oauth.ts",
      "status": "added",
      "additions": 145,
      "deletions": 0,
      "patch": "diff content here..."
    },
    {
      "path": "src/auth/session.ts",
      "status": "modified",
      "additions": 12,
      "deletions": 3,
      "patch": "diff content here..."
    }
  ],
  
  "diff_summary": {
    "total_files": 8,
    "total_additions": 342,
    "total_deletions": 15,
    "primary_languages": ["TypeScript", "JavaScript"],
    "file_types": {
      "source": 6,
      "test": 2,
      "config": 0,
      "docs": 0
    }
  },
  
  "related_code_context": {
    "src/auth/oauth.ts": {
      "full_file_content": "// Complete file content for new files...",
      "related_files": [
        {
          "path": "src/auth/types.ts",
          "content": "export interface AuthProvider { ... }",
          "relationship": "Defines types used by oauth.ts",
          "lines": 45
        },
        {
          "path": "src/auth/session.ts",
          "content": "export class SessionManager { ... }",
          "relationship": "OAuth integrates with existing session management",
          "lines": 120
        }
      ],
      "usage_examples": [
        {
          "file": "src/routes/auth.ts",
          "line": 42,
          "code": "const oauth = new OAuthProvider(config);\nawait oauth.authenticate(req);"
        }
      ],
      "tests": [
        {
          "path": "src/auth/__tests__/oauth.test.ts",
          "content": "describe('OAuthProvider', () => { ... })",
          "coverage": "85%"
        }
      ],
      "similar_implementations": [
        {
          "path": "src/auth/saml.ts",
          "reason": "Similar authentication provider pattern",
          "key_differences": "SAML uses XML, OAuth uses JSON"
        }
      ]
    }
  },
  
  "codebase_patterns": {
    "string_concatenation_for_queries": {
      "count": 12,
      "examples": ["src/db/users.ts:42", "src/db/posts.ts:67"]
    },
    "direct_db_access_in_services": {
      "count": 8,
      "examples": ["src/services/user.ts:23", "src/services/auth.ts:45"]
    },
    "error_without_rollback": {
      "count": 5,
      "examples": ["src/services/payment.ts:89"]
    }
  },
  
  "architectural_context": {
    "patterns": [
      {
        "name": "Repository Pattern",
        "usage": "Used for all database access",
        "examples": ["src/repositories/UserRepository.ts"]
      },
      {
        "name": "Service Layer",
        "usage": "Business logic separated from controllers",
        "examples": ["src/services/"]
      }
    ],
    "documentation": [
      {
        "type": "ADR",
        "title": "ADR-001: Database Access Pattern",
        "path": "docs/adr/001-database-access.md",
        "summary": "All DB access must go through repository layer"
      }
    ]
  },
  
  "review_history": {
    "previous_reviews": [
      {
        "date": "2024-01-15",
        "reviewer": "OpenCode",
        "commit": "abc123",
        "unresolved_threads": 0
      }
    ],
    "suggested_mode": "first_review"
  },
  
  "focus_areas": [
    "OAuth2 security implementation",
    "Token storage and validation", 
    "Error handling in auth flow",
    "Integration with existing session management"
  ]
}
```

## Field Descriptions

### `pr_metadata`
Basic PR information from GitHub API. Always included.

### `pr_analysis`
Orchestrator's understanding of PR intent, constraints, and scope. Helps agents understand what the PR is trying to accomplish.

### `files_changed`
List of all modified files with diff patches. Agents analyze these for issues.

### `diff_summary`
Statistical summary of changes. Helps agents understand PR size and scope.

### `related_code_context`
**NEW**: For each changed file, provides relevant surrounding code context to help agents understand how the changes fit into the broader codebase.

**Purpose**: Agents shouldn't review code in isolation. They need to understand:
- What code depends on the changed file (usage examples)
- What code the changed file depends on (imports, types)
- How similar functionality is implemented elsewhere (patterns)
- What tests exist for this code

**Structure per changed file**:
- `full_file_content`: Complete content for new/small files (<100 lines)
- `related_files`: Dependencies and dependents with their content
  - Prioritizes: direct imports > usage sites > type definitions
  - Includes relationship explanation
- `usage_examples`: Real examples of how this code is used in the codebase
- `tests`: Related test files and coverage info
- `similar_implementations`: Comparable patterns elsewhere for consistency checking

**Example Use Cases**:
1. **Configuration changes**: Show how config is loaded and used at runtime
2. **API changes**: Show full request/response flow, middleware, validators  
3. **Database changes**: Show repository layer, service layer, migrations
4. **Utility functions**: Show call sites and how similar utilities are implemented

**Context Size Limits**:
- Max 500 lines of context per changed file
- Max 10 changed files with context (prioritize most significant)
- Prefer excerpts over full files for large modules

### `codebase_patterns`
Patterns found across the codebase with occurrence counts. Critical for confidence-based severity assignment.

**Usage**: If agent finds pattern that appears 10+ times in codebase, it's likely intentional → downgrade severity.

### `architectural_context`
Known patterns and documentation in the codebase. Helps agents align suggestions with existing architecture.

### `review_history`
Previous OpenCode reviews and their status. Determines review mode (first/re-review/incremental).

### `focus_areas`
Orchestrator-suggested areas to pay attention to based on PR content. Optional guidance for agents.

## Usage by Agents

Each specialist agent receives this entire context and uses relevant portions:

**code-quality-reviewer**:
- Uses: `architectural_context`, `codebase_patterns`, `pr_analysis.constraints`
- Focus: Ensuring code aligns with existing patterns and architecture

**security-reviewer**:
- Uses: `focus_areas`, `codebase_patterns`, `pr_analysis.intent`
- Focus: Security vulnerabilities, especially in focus areas

**performance-reviewer**:
- Uses: `diff_summary`, `codebase_patterns`, `files_changed`
- Focus: Performance regressions, inefficient algorithms

## Extension

Orchestrator can add additional context fields based on PR characteristics:

```json
{
  "security_context": {
    "touches_auth": true,
    "touches_crypto": false,
    "external_apis": ["google.com/oauth2", "github.com/oauth"]
  },
  
  "performance_context": {
    "database_changes": true,
    "loops_over_collections": 5,
    "async_operations": 12
  }
}
```

Agents should gracefully handle missing optional fields.

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

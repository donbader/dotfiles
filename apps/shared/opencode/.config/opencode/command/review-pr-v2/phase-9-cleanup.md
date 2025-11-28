# Phase 8: Cleanup Worktree

If a worktree was created, clean it up after posting review.

```bash
if [ "$use_worktree" = true ]; then
  # Return to original directory
  cd - > /dev/null
  
  # Remove worktree
  git worktree remove "$worktree_dir" --force
  
  echo "=== Cleaned up worktree ==="
fi
```

**Key points**:
- Always clean up worktrees to avoid orphaned directories
- Use `--force` to handle uncommitted changes
- Return to original directory before removal

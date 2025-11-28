# Task {{TASK_NUMBER}}: {{TASK_TITLE}}

**Status**: ⏳ PENDING
**Batch**: {{BATCH_NUMBER}}
**Dependencies**: {{DEPENDENCIES}}
**Assigned**: {{TIMESTAMP}}
**Started**: _Not started_
**Completed**: _Not completed_

## Objective

{{OBJECTIVE}}

## Context

{{CONTEXT}}

## Instructions

{{INSTRUCTIONS}}

## Expected Deliverables

{{DELIVERABLES}}

## Constraints

{{CONSTRAINTS}}

## Results

_This section will be filled by the subagent executing the task._

### Summary
_Brief summary of what was accomplished_

### Details
_Detailed findings, code changes, or other outputs_

### Files Modified
_List of files that were created or modified_

### Issues Encountered
_Any problems or challenges_

### Notes
_Additional observations or recommendations_

## Progress Log

_This section will be updated incrementally as the task is executed. Each entry should include a timestamp and description of progress._

---

**Instructions for Subagent (Worker Agent)**:
1. Update Status to 🔄 IN_PROGRESS when you start
2. Update Started timestamp
3. Append initial entry to Progress Log
4. Execute all instructions in the "Instructions" section
5. Log progress after each major step (append to Progress Log)
6. Check off deliverables as you complete them
7. Fill in the "Results" section with your findings
8. Update Status to ✅ COMPLETED (or ❌ FAILED if errors occur)
9. Update Completed timestamp
10. Append final entry to Progress Log

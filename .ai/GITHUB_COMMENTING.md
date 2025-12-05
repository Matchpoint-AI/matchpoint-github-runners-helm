# GitHub Commenting Protocol for AI Agents

## Core Principle

**GitHub Issue Comments = Your RAM**

As an AI agent, you are stateless. Your local context can be compacted or lost at any time. GitHub issue comments serve as your persistent state machine, allowing you to resume work seamlessly after any interruption.

## Prerequisites (MANDATORY)

**NEVER start work without a GitHub issue.**

If a user asks you to do something and there's no issue:
1. **Create an issue immediately** using `gh issue create`
2. Comment on it with your plan
3. Create a worktree
4. Start work

Even for "quick fixes" - the issue provides:
- Audit trail
- Context for future reference
- State persistence
- PR linkage

## Comment Frequency

**CRITICAL RULE: Comment every 3-5 minutes during active work.**

### Why Every 3-5 Minutes?

- **Context Resilience**: Protects against context auto-compaction
- **State Recovery**: Enables resumption from exact point of failure
- **Transparency**: User can track progress in real-time
- **Debugging**: Creates audit trail for troubleshooting
- **Collaboration**: Other agents can pick up where you left off

### What Constitutes "Active Work"?

Comment during:
- Code editing sessions
- File analysis
- Test runs
- Build processes
- Deployment operations
- Investigation/debugging
- Any task longer than 5 minutes

## Status Tags

Use these tags consistently:

| Tag | Purpose | When to Use |
|-----|---------|-------------|
| `[STARTING]` | Beginning work | First comment on issue |
| `[PLANNING]` | Design & strategy | Before implementation |
| `[SETUP]` | Environment prep | Creating worktrees, deps |
| `[ANALYSIS]` | Investigation | Reading files, debugging |
| `[EDITING]` | Code changes | Writing/modifying code |
| `[TESTING]` | Validation | Test execution, linting |
| `[BLOCKED]` | Stuck/waiting | Dependencies, CI issues |
| `[DISCOVERY]` | Finding issues | Bugs, tech debt found |
| `[VICTORY]` | Task complete | Success, ready for merge |
| `[FAILED]` | Task failed | Errors, need to retry |

## Comment Structure

```markdown
[STATUS_TAG] Brief headline of what you're doing.

**Current Action:** Specific task in progress
**Files Changed:** List of modified files (if applicable)
**Status:** Progress indicator (e.g., "3/10 files updated")
**Next Steps:** What's coming next
**Blockers:** Any issues encountered (if applicable)
```

## Example Comments

### Starting Work

```markdown
[STARTING] Beginning work on Terraform node pool scaling.

**Approach:** Update node_count variable and add auto-scaling config
**Files to Modify:**
- `terraform/modules/spot/variables.tf`
- `terraform/modules/spot/main.tf`

**Acceptance Criteria:**
- [ ] Node pool scales from 3 to 5 nodes
- [ ] Auto-scaling enabled for future growth

**Next:** Creating worktree and starting implementation.
```

### Active Editing

```markdown
[EDITING] Implementing node pool scaling in main.tf.

**Progress:** 2/4 resources configured
**Completed:**
- `node_count` variable updated
- Auto-scaling block added

**In Progress:** Configuring scaling policies
**Next:** Running terraform validate

**Files Modified:** `terraform/modules/spot/main.tf`
```

### Testing

```markdown
[TESTING] Running Terraform validation.

**Test Run:** terraform validate
**Status:** Passed
**Output:** Success! The configuration is valid.

**Next:** Running terraform plan to preview changes.
```

### Blocked

```markdown
[BLOCKED] Terraform plan failing on provider authentication.

**Error:** `Error: Provider authentication failed`
**Root Cause:** RACKSPACE_SPOT_API_TOKEN not available in CI
**Attempted Solutions:**
1. Verified secret exists in GitHub Secrets
2. Checked workflow has correct permissions

**Next:** Updating workflow to include token secret.
```

### Discovery (Scope Creep)

```markdown
[DISCOVERY] Found unrelated issue while implementing scaling.

**Issue Found:** ArgoCD application using deprecated API version
**Impact:** Will fail on Kubernetes 1.29 upgrade
**Action:** Created Issue #45 to track this bug

**Current Focus:** Staying on track with node pool scaling (Issue #44)
**Rule:** Not fixing unrelated issues - maintaining focus on P0
```

### Victory

```markdown
[VICTORY] CI passed. Node pool scaling implemented.

**Changes:**
- Updated `node_count` from 3 to 5
- Added auto-scaling configuration (min: 3, max: 10)

**PR:** #47
**Status:** Ready for auto-merge

**Next:** Moving to next P0 issue in queue.
```

## Recovery Protocol

If you lose context:

1. **Read the issue description** - Understand the goal
2. **Read comments in chronological order** - Understand what's been done
3. **Check out the branch** mentioned in setup comment
4. **Verify file changes** with `git status` and `git diff`
5. **Continue from last comment's "Next Steps"**

## Documentation Anti-Patterns

**NEVER create transient/ephemeral markdown files:**

- ❌ `*_REPORT.md`
- ❌ `*_ANALYSIS.md`
- ❌ `*_COMPLETED.md`
- ❌ `*_STATUS.md`
- ❌ `WORKING_STATE.md`

**Use GitHub Issues instead:**

- ✅ Document progress in issue comments
- ✅ Document findings in issue comments
- ✅ Document decisions in issue comments
- ✅ Document blockers in issue comments

**Why?**
- Issue comments persist across sessions
- Issue comments are searchable
- Issue comments are linked to PRs
- Markdown files clutter the repository
- Markdown files don't integrate with project management

## Proactive Issue Creation

### When to Create New Issues

**Create a new issue when you discover:**

1. **Bugs**: Error patterns, incorrect behavior
2. **Tech Debt**: Code duplication, deprecated patterns
3. **Documentation Gaps**: Missing docs, outdated info
4. **Testing Gaps**: Missing test coverage
5. **Improvement Opportunities**: Workflow enhancements

### How to Create Issues

```bash
gh issue create --repo Matchpoint-AI/matchpoint-github-runners-helm \
  --title "Clear, descriptive title" \
  --body "$(cat <<'EOF'
## Problem

[Description of what you discovered]

## Impact

[Why this matters]

## Proposed Solution

[How to fix it]

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Priority

**[High|Medium|Low]** - [Justification]
EOF
)"
```

### Link Back to Current Work

After creating a new issue, always comment in your current thread:

```markdown
[DISCOVERY] Found unrelated issue while working on node pool scaling.

**Issue Found:** [Brief description]
**Created:** Issue #45
**Current Focus:** Staying on task with Issue #44
```

## Integration with Git Workflow

### Before Starting Work

```bash
# 1. Ensure issue exists
gh issue view <issue-number>

# 2. Comment that you're starting
gh issue comment <issue-number> --body "[STARTING] Beginning work on..."

# 3. Create worktree
git worktree add ../runners-helm-<issue-number> -b fix/<issue-number> main
```

### During Work

```bash
# Commit frequently
git add .
git commit -m "infra: descriptive message"
git push  # IMMEDIATELY after every commit

# Comment on progress every 3-5 minutes
gh issue comment <issue-number> --body "[UPDATE] Progress update..."
```

### After Completing Work

```bash
# Create PR
gh pr create --title "Fix: Description" --body "Closes #<issue-number>"

# Final comment
gh issue comment <issue-number> --body "[VICTORY] PR created, CI running..."
```

## Summary

1. **Always have an issue** before starting work
2. **Comment every 3-5 minutes** during active work
3. **Use status tags** for clear state tracking
4. **Create new issues** for discovered problems
5. **Never create ephemeral markdown files**
6. **Use issues as your persistent memory**

Your comments are not just updates - they are your memory.

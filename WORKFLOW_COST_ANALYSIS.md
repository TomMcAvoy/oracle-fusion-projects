# GitHub Actions Cost & Queue Analysis

## 💰 Current Cost: $0/month ✅

### Why $0?
- **All workflows use `self-hosted` runners**
- **GitHub-hosted runners**: $0.008/minute (Linux), $0.016/minute (Windows/macOS)
- **Self-hosted runners**: FREE compute (you pay for infrastructure only)

## ⏱️ Queue Issues = Resource Constraint, Not Cost

### Root Cause
- **Available runners**: 1 (`vault-runner-ubuntu-vm1`)
- **Workflows per git push**: 5+ workflows auto-trigger
- **Execution**: Sequential (1 job at a time)

### Current Workflow Triggers
```bash
# These ALL trigger on git push:
- async-state-machine.yml
- pubsub-async-pipeline.yml  
- ci-cd.yml
- test-async-pipeline.yml
- test-validation.yml
```

## 🎯 Optimization Options

### Option 1: Reduce Auto-Triggers (Recommended)
```yaml
# Change from:
on:
  push:
    branches: [ master, main ]

# To:  
on:
  workflow_dispatch:  # Manual trigger only
```

### Option 2: Add Path Filters
```yaml
on:
  push:
    branches: [ master ]
    paths:
      - 'auth-cache/**'  # Only trigger for specific changes
```

### Option 3: More Runners
- **Self-hosted**: Add more VMs (infrastructure cost)
- **GitHub-hosted**: Switch some workflows (GitHub Actions cost)

## 📊 Cost Comparison

| Runner Type | Cost/minute | Pros | Cons |
|-------------|-------------|------|------|
| Self-hosted | $0 | Free compute, custom environment | Setup/maintenance, limited parallelism |
| GitHub-hosted | $0.008+ | Infinite parallelism, zero maintenance | Costs add up, limited customization |

## 🚀 Recommendation

**Keep using self-hosted runners** (cost-effective) but:
1. Convert most workflows to `workflow_dispatch` (manual)
2. Keep 1-2 workflows on `push` for CI/CD
3. Use path filters to prevent unnecessary runs

**Result**: Faster execution, $0 cost, less queue congestion
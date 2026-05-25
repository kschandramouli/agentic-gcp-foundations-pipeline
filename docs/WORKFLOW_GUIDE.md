# Deployment Workflow Guide

This document explains how to use the GitHub Actions Terraform deployment workflow.

## Workflow Overview

The pipeline consists of 5 main stages:

```
1. Terraform Validation       (Runs on push and PR)
   ├── Format check (terraform fmt -check)
   └── Syntax validation (terraform validate)
    
2. Security Scanning          (Runs on push and PR)
   ├── tfsec (Terraform security audit)
   └── Checkov (Compliance checks)
    
3. Terraform Plan             (Runs on push and PR)
   ├── Authenticate to GCP via WIF
   ├── Initialize Terraform
   ├── Generate execution plan
   └── Store plan artifacts
    
4. Manual Approval            (Runs only on main push)
   └── Requires manual approval before apply
    
5. Terraform Apply            (Runs only on main push, after approval)
   ├── Download saved plan
   ├── Apply changes to GCP
   └── Publish output artifacts
```

## Triggering the Workflow

### 1. Push to Main Branch

```bash
git add terraform/
git commit -m "Add cloud resources"
git push origin main
```

**What happens:**
- Validation and security scanning run immediately
- If plan stage succeeds, the apply stage waits for approval
- Once approved in GitHub UI, apply runs automatically

### 2. Pull Request to Main

```bash
git checkout -b feature/new-resources
git add terraform/
git commit -m "Add cloud resources"
git push origin feature/new-resources
# Create PR on GitHub
```

**What happens:**
- Validation and security scanning run
- Plan stage shows you what will change
- Plan appears in PR comments
- **No apply happens** until merged to main

### 3. Manual Workflow Dispatch

Go to your GitHub repository:
1. Click **Actions**
2. Select **Terraform Plan and Apply**
3. Click **Run workflow**
4. Optional: Select custom Terraform version or plan-only mode
5. Click **Run workflow**

## During the Workflow

### Monitoring Execution

1. Go to **Actions** tab in your GitHub repository
2. Click the most recent workflow run
3. Click a job to see detailed logs
4. Watch for:
   - ✓ Green checks = Success
   - ✗ Red X = Failure
   - ⏳ Yellow clock = In progress

### Understanding the Output

#### Terraform Plan Stage Output

```
Planning infrastructure changes...

+ google_iam_workload_identity_pool.github_pool
+ google_iam_workload_identity_pool_provider.github_provider
+ google_service_account.github_actions
+ google_project_iam_member.github_actions_roles["roles/editor"]

Plan: 4 to add, 0 to change, 0 to destroy
```

#### Security Scanning Results

**tfsec warnings:**
```
Problem 1: [aws-s3-enable-versioning] S3 Bucket versioning not enabled
  No: resource 'google_storage_bucket' 'my_bucket'
```

**Checkov violations:**
```
Check: CKV_GOOGLE_1: "Ensure that Cloud Storage bucket is not anonymously or publicly accessible"
```

### PR Comments

The workflow automatically posts a plan summary to your PR:

```
## 📋 Terraform Plan Summary

### Plan Details
+ google_storage_bucket.example
+ google_compute_instance.example

Plan: 2 to add, 0 to change, 0 to destroy

Status: success
Plan created at: 2026-04-11T10:30:00Z
```

## Approving Changes

### For Main Branch Pushes

Once the plan stage succeeds:

1. Go to **Actions** tab
2. Click the workflow run
3. Look for a pending approval task
4. Scroll down and click **Approve and deploy**
5. Wait for the apply stage to complete

OR use GitHub Environments:
1. Go to **Settings** → **Environments** → **Production**
2. Review pending deployments
3. Click **Approve**

## After Deployment

### Accessing Outputs

After apply completes:

1. Go to the workflow run
2. Scroll to the **Terraform Apply** job
3. It shows the final state and outputs
4. Outputs are also saved as artifacts (30-day retention)

To download outputs:
1. In the workflow run page
2. Scroll to **Artifacts** section
3. Click **terraform-outputs**

### Deployment Summary

Each successful apply posts a summary showing:
- Service account email
- WIF provider resource
- GCP project configuration
- Deployment timestamp

## Handling Failures

### Validation Failures

**Issue**: `terraform fmt -check` failed

**Solution**:
```bash
# Format your Terraform files locally
terraform fmt -recursive terraform/

# Commit and push
git add terraform/
git commit -m "Fix Terraform formatting"
git push
```

### Security Scan Failures

**Issue**: tfsec or Checkov found issues

**View results:**
1. Go to **Security** tab in GitHub
2. Click **Code scanning alerts**
3. Address violations:
   - Either fix the issue
   - Or suppress with comments in code:
     ```hcl
     # tfsec:skip=AVD-AWS-0144
     resource "aws_s3_bucket" "example" {
       # ...
     }
     ```

### Plan Failures

**Common issues:**

1. **Authentication failed**
   - Check WIF_PROVIDER secret
   - Verify GCP IAM bindings

2. **Variable not set**
   - Ensure terraform.tfvars exists in terraform/ directory
   - Check for typos in variable names

3. **State lock timeout**
   - Another workflow may be running
   - Wait for other runs to complete
   - Check workflow history

### Apply Failures

**Usually caused by:**
1. Insufficient IAM permissions
2. Resource limits in GCP
3. Invalid configuration in plan

**Fix and retry:**
```bash
# Fix the issue locally
# Commit and push again
git add terraform/
git commit -m "Fix resource configuration"
git push origin main

# This triggers a new workflow run
```

## Best Practices

### 1. Always Review Plans Before Approval
- Read the plan output carefully
- Verify you understand the changes
- Check if any resources will be destroyed

### 2. Use Feature Branches
```bash
# Create feature branch
git checkout -b feature/add-database

# Make changes
terraform apply -var-file="staging.tfvars"

# Create PR and get approval
git push origin feature/add-database
```

### 3. Test in Staging First
- Use different `terraform.tfvars` for stages:
```bash
terraform apply -var-file="staging.tfvars"
terraform apply -var-file="prod.tfvars"
```

### 4. Keep Terraform Code in Sync
- Don't manually change GCP resources
- Always use Terraform
- Run `terraform import` if you need to sync state

### 5. Review Logs Regularly
- Check workflow logs for warnings
- Fix issues proactively
- Archive important deploy logs

## Command Reference

### View Workflow Status
```bash
gh workflow view terraform.yml
```

### Trigger Manual Workflow
```bash
gh workflow run terraform.yml
```

### Download Artifacts
```bash
gh run download {RUN_ID} -n terraform-outputs
```

### View Logs Locally
```bash
gh run view {RUN_ID} --log
```

## Troubleshooting Approval

### Approval Step Never Appears

**Cause**: Running on PR, not main branch

**Solution**: Only applies on main push, after successful plan

### Cannot Click Approve Button

**Cause**: Missing workflow permissions

**Solution**:
1. Go to **Settings** → **Actions** → **General**
2. Check "Allow GitHub Actions to create and approve pull requests"
3. Check if you're an approver (see GITHUB_SECRETS.md)

### Approval Stuck at Pending

**Solution**:
1. Wait 5+ minutes
2. Refresh the page
3. Check workflow logs for errors
4. Manually approve via GitHub UI

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform CI/CD Best Practices](https://www.terraform.io/cloud-docs/run/run-environment)
- [GCP Authentication](https://cloud.google.com/docs/authentication/production)

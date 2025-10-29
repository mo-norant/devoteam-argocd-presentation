# ArgoCD Beginner Tutorial - 15 Minute Hands-On Demo

Welcome to this hands-on tutorial for getting started with ArgoCD! In this 15-minute session, you'll learn the fundamentals of GitOps and deploy your first application using ArgoCD.

## Table of Contents

1. [Prerequisites & Environment Setup](#1-prerequisites--environment-setup)
2. [Installing ArgoCD](#2-installing-argocd)
3. [Accessing ArgoCD UI and CLI](#3-accessing-argocd-ui-and-cli)
4. [Registering Your Git Repository](#4-registering-your-git-repository)
5. [Creating Your First Application](#5-creating-your-first-application)
6. [Monitoring and Syncing](#6-monitoring-and-syncing)
7. [GitOps Workflow Demonstration](#7-gitops-workflow-demonstration)
8. [Optional: Rollback](#8-optional-rollback)
9. [Cleanup](#9-cleanup)
10. [Key Concepts Summary](#10-key-concepts-summary)

---

## 1. Prerequisites & Environment Setup

**Time: ~2 minutes**

Before we begin, ensure you have a local Kubernetes cluster running. We recommend either **Minikube** or **Kind** (Kubernetes in Docker).

### Option A: Minikube

If you don't have Minikube installed:

```bash
# Install Minikube (if not already installed)
# Windows (with Chocolatey):
choco install minikube

# macOS (with Homebrew):
brew install minikube

# Linux:
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

Start Minikube:

```bash
minikube start --driver=docker
```

Verify your cluster is running:

```bash
kubectl cluster-info
kubectl get nodes
```

### Option B: Kind (Kubernetes in Docker)

If you prefer Kind:

```bash
# Install Kind (if not already installed)
# Windows (with Chocolatey):
choco install kind

# macOS/Linux:
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Create a Kind cluster:

```bash
kind create cluster --name argocd-demo
```

Verify your cluster:

```bash
kubectl cluster-info --context kind-argocd-demo
```

### Verify Prerequisites

Ensure you have these tools installed and accessible:

```bash
kubectl version --client
git --version
```

**✅ Checklist:**
- [ ] Kubernetes cluster running (Minikube or Kind)
- [ ] `kubectl` configured and working
- [ ] `git` installed
- [ ] This Git repository cloned locally

---

## 2. Installing ArgoCD

**Time: ~3 minutes**

We'll install ArgoCD in a dedicated namespace using the official Kubernetes manifests.

### Create ArgoCD Namespace

```bash
kubectl create namespace argocd
```

### Install ArgoCD

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

This installs:
- ArgoCD Server (API and UI)
- ArgoCD Application Controller
- ArgoCD Repo Server
- Redis (for caching)
- Various CRDs (Application, AppProject, etc.)

### Wait for All Pods to Be Ready

Monitor the installation progress:

```bash
kubectl get pods -n argocd -w
```

Press `Ctrl+C` to stop watching. Wait until all pods show `Running` status (usually takes 2-3 minutes).

Verify everything is ready:

```bash
kubectl get pods -n argocd
```

You should see output similar to:

```
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          2m
argocd-applicationset-controller-7d5c8f6b6b-xxx     1/1     Running   0          2m
argocd-dex-server-7b4b4c7d8c-xxx                    1/1     Running   0          2m
argocd-notifications-controller-7d8f9c6b5d-xxx      1/1     Running   0          2m
argocd-redis-7d8f9c6b5d-xxx                          1/1     Running   0          2m
argocd-repo-server-7d8f9c6b5d-xxx                    1/1     Running   0          2m
argocd-server-7d8f9c6b5d-xxx                         1/1     Running   0          2m
```

### Alternative: Using the Helper Script

If you prefer automation, you can use the provided script:

```bash
chmod +x scripts/install-argocd.sh
./scripts/install-argocd.sh
```

---

## 3. Accessing ArgoCD UI and CLI

**Time: ~2 minutes**

### Access the ArgoCD UI

#### For Minikube:

Enable port-forwarding to access the ArgoCD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open your browser to: **https://localhost:8080**

#### For Kind:

Same command works:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open: **https://localhost:8080**

**Note:** Your browser may warn about the self-signed certificate. Click "Advanced" and "Proceed to localhost" (or similar option depending on your browser).

### Get Admin Password

ArgoCD creates an initial admin user. Retrieve the password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Note on Windows PowerShell:** Use this command instead:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**Default credentials:**
- **Username:** `admin`
- **Password:** (use the command above to retrieve)

### Login to the UI

1. Navigate to https://localhost:8080
2. Enter username: `admin`
3. Enter the password you retrieved above
4. Click "Sign In"

You should now see the ArgoCD dashboard!

### Install ArgoCD CLI (Optional but Recommended)

The CLI is useful for automation and troubleshooting:

#### Linux/macOS:

```bash
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
```

Or with Homebrew on macOS:

```bash
brew install argocd
```

#### Windows (PowerShell):

```powershell
# Using Scoop
scoop install argocd

# Or download manually
Invoke-WebRequest -Uri https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe -OutFile argocd.exe
# Move to a directory in your PATH
```

### Login via CLI

First, ensure the port-forward is running in a separate terminal:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then in another terminal, login:

```bash
argocd login localhost:8080 --username admin --insecure
```

Enter the password when prompted. The `--insecure` flag is needed because we're using a self-signed certificate.

---

## 4. Registering Your Git Repository

**Time: ~1 minute**

ArgoCD needs to know about your Git repository to pull Kubernetes manifests from it.

### Method 1: Using the UI

1. In the ArgoCD UI, click on the **settings icon** (gear) in the left sidebar
2. Select **Repositories**
3. Click **+ Connect Repo**
4. Configure:
   - **Type:** Git
   - **Project:** default
   - **Repository URL:** (your Git repository URL)
   - For **public repos**: No credentials needed
   - For **private repos**: Add SSH key or username/password
5. Click **Connect**

### Method 2: Using the CLI

For a public repository:

```bash
argocd repo add <YOUR_REPO_URL> --name my-repo
```

For a private repository with username/password:

```bash
argocd repo add <YOUR_REPO_URL> --name my-repo --username <USERNAME> --password <PASSWORD>
```

For a private repository with SSH:

```bash
argocd repo add <YOUR_REPO_URL> --name my-repo --ssh-private-key-path ~/.ssh/id_rsa
```

### Verify Repository Connection

Check if the repository was added successfully:

```bash
argocd repo list
```

Or check in the UI under Settings → Repositories. You should see a green checkmark indicating the connection is successful.

**✅ Checklist:**
- [ ] Repository registered in ArgoCD
- [ ] Connection status shows success
- [ ] Repository is accessible

---

## 5. Creating Your First Application

**Time: ~2 minutes**

Now we'll create an ArgoCD Application object that will deploy the guestbook application from your Git repository.

### Review the Guestbook Manifests

First, let's check what we'll be deploying. The guestbook manifests are located in `manifests/guestbook/`:

- `namespace.yaml` - Creates the guestbook namespace
- `deployment.yaml` - Deploys the guestbook frontend
- `service.yaml` - Exposes the guestbook service
- `kustomization.yaml` - Kustomize configuration (optional)

### Method 1: Create Application via UI

1. In the ArgoCD UI, click **+ New App**
2. Fill in the application details:
   - **Application Name:** `guestbook`
   - **Project Name:** `default`
   - **Sync Policy:** Manual (we'll enable auto-sync later)
3. Under **Source:**
   - **Repository URL:** (select your registered repository)
   - **Revision:** `HEAD` (latest commit)
   - **Path:** `manifests/guestbook`
4. Under **Destination:**
   - **Cluster URL:** `https://kubernetes.default.svc` (same cluster)
   - **Namespace:** `guestbook`
5. Click **Create**

### Method 2: Create Application via CLI

Create the application using the CLI:

```bash
argocd app create guestbook \
  --repo <YOUR_REPO_URL> \
  --path manifests/guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook \
  --sync-policy manual
```

### Method 3: Create Application via YAML (Declarative)

Create a file `argocd-apps/guestbook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: <YOUR_REPO_URL>
    targetRevision: HEAD
    path: manifests/guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```bash
kubectl apply -f argocd-apps/guestbook.yaml
```

### Sync the Application

After creating the application, you need to sync it initially:

#### Via UI:
1. Click on the `guestbook` application
2. Click the **Sync** button
3. Review the changes and click **Synchronize**

#### Via CLI:
```bash
argocd app sync guestbook
```

### Verify Deployment

Check if the application is syncing:

```bash
argocd app get guestbook
```

Or watch in the UI - you should see resources being created.

Check the actual Kubernetes resources:

```bash
kubectl get all -n guestbook
```

You should see the guestbook deployment and service running.

**✅ Checklist:**
- [ ] Application created in ArgoCD
- [ ] Initial sync completed
- [ ] Guestbook pods running
- [ ] Application shows "Healthy" and "Synced" status

### Optional: Create a Second Application (PingPong)

Let's create another application to demonstrate ArgoCD managing multiple workloads. The PingPong application responds to HTTP requests with "Pong! Version: v1.0.0".

The manifests are located in `manifests/pingpong/`:

- `namespace.yaml` - Creates the pingpong namespace
- `deployment.yaml` - Deploys the pingpong service (responds with version info)
- `service.yaml` - Exposes the pingpong service
- `kustomization.yaml` - Kustomize configuration

#### Create PingPong Application via CLI

```bash
argocd app create pingpong \
  --repo <YOUR_REPO_URL> \
  --path manifests/pingpong \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace pingpong \
  --sync-policy automated \
  --auto-prune \
  --self-heal \
  --sync-option CreateNamespace=true
```

Or use the helper script:

```bash
chmod +x scripts/setup-pingpong-app.sh
./scripts/setup-pingpong-app.sh <YOUR_REPO_URL>
```

#### Sync and Verify PingPong

```bash
# Sync if not auto-syncing
argocd app sync pingpong

# Check status
argocd app get pingpong
kubectl get all -n pingpong
```

#### Test the PingPong Service

Port-forward to test the service:

```bash
kubectl port-forward svc/pingpong -n pingpong 8080:80
```

In another terminal, test it:

```bash
curl http://localhost:8080
```

You should see: `Pong! Version: v1.0.0`

#### Update PingPong Version

To demonstrate version updates, edit `manifests/pingpong/deployment.yaml` and change the version in the args:

```yaml
args:
  - -listen=:8080
  - -text="Pong! Version: v2.0.0"  # Updated version
```

Also update the version label:

```yaml
labels:
  app: pingpong
  version: "v2.0.0"
```

Commit and push:

```bash
git add manifests/pingpong/deployment.yaml
git commit -m "Update pingpong to v2.0.0"
git push origin main
```

ArgoCD will detect the change and sync automatically (if auto-sync is enabled), or refresh and sync manually:

```bash
argocd app get pingpong --refresh
argocd app sync pingpong
```

Test the new version:

```bash
curl http://localhost:8080
# Should now show: Pong! Version: v2.0.0
```

**✅ Checklist for PingPong:**
- [ ] PingPong application created
- [ ] Application synced and healthy
- [ ] Service responds with version info
- [ ] Version update demonstrated

---

## 6. Monitoring and Syncing

**Time: ~1 minute**

### Understanding Application Status

In the ArgoCD UI, you'll see several status indicators:

- **Sync Status:** Shows if the cluster state matches Git
  - ✅ **Synced** - Cluster matches Git
  - 🟡 **OutOfSync** - Differences detected
  - 🔴 **Unknown** - Cannot determine status

- **Health Status:** Shows the health of Kubernetes resources
  - ✅ **Healthy** - Resources are healthy
  - 🟡 **Degraded** - Some resources degraded
  - 🔴 **Missing** - Resources not found
  - ⚠️ **Suspended** - Application suspended

### Viewing Resource Details

1. Click on the `guestbook` application in the UI
2. Explore the **Resource Tree** - shows all Kubernetes resources
3. Click on individual resources to see details
4. View the **Timeline** tab for sync history
5. Check the **Logs** tab for application controller logs

### Manual Sync Operations

Via CLI, sync the application:

```bash
# Sync the application
argocd app sync guestbook

# Sync with prune (removes resources not in Git)
argocd app sync guestbook --prune

# Dry-run to see what would change
argocd app sync guestbook --dry-run
```

### Health Monitoring

ArgoCD continuously monitors your application health by checking:
- Deployment rollout status
- Pod readiness
- Resource quotas
- Custom health checks (if configured)

Check health status:

```bash
argocd app get guestbook
```

**What you should see:**
- All pods in "Running" state
- Deployment showing "Healthy"
- Service endpoints ready
- Application overall status: "Healthy" and "Synced"

---

## 7. GitOps Workflow Demonstration

**Time: ~3 minutes**

This is the heart of GitOps! We'll make a change in Git and watch ArgoCD automatically sync it to the cluster.

### Scenario: Update the Guestbook Image

Let's update the guestbook deployment to use a different image tag.

### Step 1: Edit the Deployment

Open `manifests/guestbook/deployment.yaml` and find the image specification. For example, if it currently has:

```yaml
image: gcr.io/heptio-images/ks-guestbook-demo:0.2
```

Change it to:

```yaml
image: gcr.io/heptio-images/ks-guestbook-demo:0.3
```

Or change any other configuration like replica count:

```yaml
replicas: 3  # Increase from 1 or 2
```

### Step 2: Commit and Push to Git

```bash
git add manifests/guestbook/deployment.yaml
git commit -m "Update guestbook image to v0.3"
git push origin main
```

### Step 3: Enable Auto-Sync (If Not Already Enabled)

For automatic synchronization, enable auto-sync on the application:

#### Via UI:
1. Click on the `guestbook` application
2. Click **App Details** → **Sync Policy**
3. Enable **Auto-Create Namespace** (if needed)
4. Enable **Auto-Sync**
5. Optionally enable **Self-Heal**
6. Click **Save**

#### Via CLI:
```bash
argocd app set guestbook --sync-policy automated --auto-prune --self-heal
```

Or update the Application YAML:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Step 4: Observe the Change

ArgoCD polls the Git repository (default: every 3 minutes) or you can trigger immediately:

```bash
# Refresh the app to detect changes immediately
argocd app get guestbook --refresh
```

Watch the sync happen in real-time:

```bash
# Watch the application status
watch -n 1 argocd app get guestbook
```

Or observe in the UI:
1. Go to the `guestbook` application
2. You should see it change to "OutOfSync" status
3. If auto-sync is enabled, it will automatically sync
4. If manual sync, click the **Sync** button
5. Watch as ArgoCD updates the deployment
6. New pods will be rolled out
7. Status returns to "Synced" and "Healthy"

### Step 5: Verify the Change

Check that the new image is deployed:

```bash
kubectl describe deployment guestbook -n guestbook | grep Image
```

You should see your updated image version!

```bash
kubectl get pods -n guestbook -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Understanding GitOps Flow

**What just happened:**

1. ✅ **Single Source of Truth:** Git repository contains the desired state
2. ✅ **Declarative:** We described what we want, not how to do it
3. ✅ **Automated:** ArgoCD detected the change and applied it
4. ✅ **Versioned:** The change is tracked in Git history
5. ✅ **Auditable:** Full history in Git commits

**Key Takeaway:** Git is the source of truth. Any change to the cluster goes through Git first, ensuring version control and audit trails.

---

## 8. Optional: Rollback

**Time: ~2 minutes**

One of ArgoCD's powerful features is easy rollback to previous versions.

### Scenario: Rollback to Previous Image Version

Let's say the new image has a bug. We can quickly rollback.

### Method 1: Rollback via Git (GitOps Way)

The proper GitOps way is to revert the commit:

```bash
# See commit history
git log --oneline manifests/guestbook/deployment.yaml

# Revert the last commit
git revert HEAD

# Or reset to a specific commit (if you haven't pushed yet)
git reset --hard <previous-commit-hash>

# Push the revert
git push origin main
```

ArgoCD will detect the change and rollback automatically (if auto-sync is enabled).

### Method 2: Rollback via ArgoCD UI

1. Click on the `guestbook` application
2. Open the **History** tab
3. Find a previous sync that worked
4. Click on it and select **Sync** to that revision
5. This creates a temporary sync but **doesn't update Git**

**Note:** Method 2 is a temporary rollback. For permanent rollback, use Method 1 to update Git.

### Method 3: Rollback via CLI

```bash
# List sync history
argocd app history guestbook

# Rollback to a specific revision
argocd app rollback guestbook <REVISION_ID>
```

### Verify Rollback

```bash
argocd app get guestbook
kubectl get deployment guestbook -n guestbook -o yaml | grep image:
```

You should see the previous image version.

### Best Practice

**Always rollback via Git** to maintain the GitOps principle: Git as the single source of truth. ArgoCD rollbacks should only be used for emergency situations and then immediately followed by a Git commit.

---

## 9. Cleanup

**Time: ~1 minute**

After the tutorial, clean up all resources.

### Remove the Applications

Delete both applications (guestbook and pingpong):

```bash
# Delete the applications (this will delete all managed resources)
argocd app delete guestbook
argocd app delete pingpong
```

Or via UI:
1. Click on each application (`guestbook` and `pingpong`)
2. Click the three dots menu (⋮)
3. Select **Delete**
4. Confirm deletion

### Remove the Git Repository (Optional)

```bash
argocd repo rm <YOUR_REPO_URL>
```

### Uninstall ArgoCD (Optional)

If you want to remove ArgoCD completely:

```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

### Stop the Cluster (Optional)

For Minikube:
```bash
minikube stop
# Or delete completely:
minikube delete
```

For Kind:
```bash
kind delete cluster --name argocd-demo
```

### Using the Cleanup Script

We've provided a cleanup script for convenience that removes both applications:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

To also remove ArgoCD:

```bash
./scripts/cleanup.sh yes
```

**✅ Checklist:**
- [ ] Applications deleted (guestbook and pingpong)
- [ ] Resources cleaned up
- [ ] Namespaces removed
- [ ] ArgoCD uninstalled (if desired)
- [ ] Cluster stopped (if desired)

---

## 10. Key Concepts Summary

### GitOps Principles

ArgoCD implements GitOps, which means:

1. **Git as Single Source of Truth**
   - All configuration and manifests live in Git
   - No manual `kubectl apply` commands
   - Git history provides full audit trail

2. **Declarative Configuration**
   - You describe **what** you want (desired state)
   - ArgoCD figures out **how** to achieve it
   - No imperative commands needed

3. **Automated Synchronization**
   - ArgoCD continuously compares Git state with cluster state
   - Detects drift and can auto-heal
   - Ensures cluster matches Git

4. **Self-Healing**
   - If someone manually changes the cluster, ArgoCD detects it
   - Can automatically revert to Git state (if enabled)
   - Prevents configuration drift

5. **Versioned Deployment History**
   - Every change tracked in Git
   - Easy rollback to any previous version
   - Full audit trail for compliance

### ArgoCD Workflow

```
┌─────────┐         ┌──────────┐         ┌──────────┐
│   Git   │────────▶│  ArgoCD  │────────▶│Kubernetes│
│  Repo   │  Pull   │  Server  │  Apply  │ Cluster  │
│         │◀────────│          │◀────────│          │
└─────────┘ Monitor └──────────┘ Status  └──────────┘
              │
              │ Compare
              ▼
         Desired State
         vs
         Actual State
```

1. **Git Repository** contains Kubernetes manifests (desired state)
2. **ArgoCD** monitors Git repository
3. **ArgoCD** compares desired state (Git) with actual state (cluster)
4. **ArgoCD** applies differences to cluster
5. **ArgoCD** monitors cluster health and reports status

### ArgoCD Components

- **ArgoCD Server**: API and UI server
- **Application Controller**: Manages application lifecycle and sync
- **Repo Server**: Caches Git repositories
- **Redis**: Caching layer
- **CRDs**: Application, AppProject, etc.

### Best Practices

1. **Use Namespace Isolation**: Separate namespaces for different applications
2. **Enable Auto-Sync Carefully**: Only after thorough testing
3. **Use App Projects**: Organize applications into projects with RBAC
4. **Monitor Health**: Set up alerts for OutOfSync or unhealthy states
5. **Version Control**: Always use Git tags/branches for releases
6. **Review Before Sync**: Use manual sync during development, auto-sync in production

### Common Use Cases

- **Continuous Deployment**: Automatically deploy from Git branches
- **Multi-Environment**: Manage dev/staging/prod from one Git repo
- **Canary Deployments**: Gradual rollout with Argo Rollouts
- **Multi-Cluster**: Deploy same app to multiple Kubernetes clusters
- **Helm/Kustomize**: Support for various packaging tools

---

## Troubleshooting

### Port-Forward Keeps Dropping

Run the port-forward command in a dedicated terminal and keep it running:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Application Stuck in "Pending" Status

Check if the Git repository is accessible:

```bash
argocd repo get <YOUR_REPO_URL>
```

Verify the path exists:

```bash
argocd app get guestbook --refresh
```

### Pods Not Starting

Check pod logs:

```bash
kubectl get pods -n guestbook
kubectl describe pod <POD_NAME> -n guestbook
kubectl logs <POD_NAME> -n guestbook
```

### Application Shows "Unknown" Health

This usually means ArgoCD can't determine health. Check:

```bash
argocd app get guestbook
kubectl get all -n guestbook
```

### Sync Failed

Check sync logs:

```bash
argocd app logs guestbook
```

Or view in UI: Application → Logs tab

---

## Next Steps

Congratulations! You've completed the ArgoCD tutorial. Here's what to explore next:

- **App Projects**: Organize applications and manage RBAC
- **Multi-Environment**: Set up dev/staging/prod pipelines
- **Helm Integration**: Deploy Helm charts with ArgoCD
- **Kustomize**: Advanced overlays and patches
- **Argo Rollouts**: Canary and blue-green deployments
- **Multi-Cluster**: Deploy across multiple Kubernetes clusters
- **Webhooks**: Trigger syncs on Git webhook events
- **Notifications**: Slack, email, or webhook notifications

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Best Practices](https://www.gitops.tech/)
- [ArgoCD Slack Community](https://argoproj.github.io/community/join-slack)

---

**Happy GitOps! 🚀**


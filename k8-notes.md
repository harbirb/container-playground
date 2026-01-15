# Kubernetes Notes

## Core Concepts

- **Kind**: Kubernetes IN Docker. It runs Kubernetes "nodes" as Docker containers on your local machine.
- **Node**: A worker machine (VM or physical server) where Kubernetes runs your workloads.
- **Pod**: The smallest deployable unit in Kubernetes.
  - Can contain one or more containers (e.g., a main app container + a sidecar logger).
  - In Kind, the "node" is just another container running on your host.
- **Roles**:
  - `kind`: Handles cluster infrastructure (spinning up nodes).
  - `kubectl`: Handles workloads and configuration inside the cluster (talking to the API).

## Basic Workflow

1. **Create Cluster**:
   ```bash
   kind create cluster --name <cluster-name>
   ```
2. **Interact with API**: Use `kubectl` to talk to the control plane.
3. **Load Images**:
   Build your image locally, then load it into the Kind cluster so it's available to the nodes:
   ```bash
   kind load docker-image my-app:v1 --name <cluster-name>
   ```
4. **Run a Pod**:
   Imperatively start a pod (instance of your image):
   ```bash
   kubectl run <pod-name> --image=my-app:v1
   ```
5. **Manage Pods**:
   - **View Logs**: `kubectl logs <pod-name>`
   - **Delete Pod**: `kubectl delete pod <pod-name>`
   - **List Resources**: `kubectl get nodes` or `kubectl get pods`

## Important Configuration Details

- **Image Pull Policy**: Kubernetes tries to pull images from the internet (Docker Hub) by default.
  - For local development with Kind, use a specific tag (e.g., `:v1`) or set:
    ```yaml
    imagePullPolicy: Never
    ```
- **Restart Policy**: Pods default to `Always` restarting.
  - For one-off tasks (like jobs), use `--restart=Never`.
    - (I forgot to use this for my hello-world pod and it silently crashed and restarted for 48 hours in the background. Ouch.)

## Deep Dive: Entrypoints & Shells

**Question:** When creating a pod, the entrypoint command does not execute within a shell. How is that possible?

**Answer:**

- At the lowest level, Linux exposes a syscall `execve()` which runs a binary directly.
- Shells (like `bash` or `sh`) are just convenience programs that parse text and call `execve()` for you.
- The container runtime calls `execve()` directly with your provided command and arguments, bypassing the shell entirely.
- **Implication:** You cannot use shell features like `&&`, `|`, or `>` unless you explicitly invoke a shell (e.g., `["/bin/sh", "-c", "..."]`).

## Quick Start: Running a Pod

Step-by-step guide to running the `samtools` pod.

```bash
# 1. Build your image
docker build -f dockerfile.optimizedmusl . -t samtools-final

# 2. Upload it to your cluster (default cluster name is 'kind')
kind load docker-image samtools-final

# 3. Create the pod specified by your config
kubectl apply -f pod.yaml

# 4. Observe the pod logs
kubectl logs samtools-pod

# 5. Delete the pod (cleanup)
kubectl delete pod samtools-pod
```

## Jobs & Resilience

- A job is a one-off task that runs to completion and stops.
- In bio, we rarely run services (long-running servers). We run "jobs" (start, process data, finish).
- If a job fails, it will be retried automatically (configure retries with `backoffLimit`).

```bash
# Create the job specified by your config
kubectl apply -f job.yaml

# Get job status
kubectl describe job samtools-job

# Delete the job (cleanup)
kubectl delete job samtools-job
```

## Persistence (PVCs)

- When a container finishes, its filesystem is destroyed. To persist data, we use PVs and PVCs.
- PVs are like disks, PVCs are like files, provisioned by Kubernetes.
- Pods can mount PVCs at a path and write to it like a file.

```bash
# Create the PVC specified by your config
kubectl apply -f pvc.yaml

# Create the job specified by your config
kubectl apply -f job-persist.yaml

# Delete the job (cleanup)
kubectl delete job samtools-job

# Verify data persistence.
# Create a debugging pod that mounts the same PVC. Replace YOUR_PVC_NAME.
# Run it and check if `/data/output.txt` exists.
kubectl run pvc-inspector --image=busybox -it --rm --restart=Never \
  --overrides='
  {
    "spec": {
      "containers": [
        {
          "name": "inspector",
          "image": "busybox",
          "args": ["sh"],
          "stdin": true,
          "tty": true,
          "volumeMounts": [{ "mountPath": "/data", "name": "my-vol" }]
        }
      ],
      "volumes": [{ "name": "my-vol", "persistentVolumeClaim": { "claimName": "YOUR_PVC_NAME" } }]
    }
  }'
```

## Mini-Pipeline (Manual)

- We can chain jobs together manually by mounting them to the same PVC.
- Create PVC. Run Job 1 (Download data to PVC). Run Job 2 (Process data in PVC).
- By saving intermediate data in PVCs, we create a checkpoint. If step 2 fails, we can restart from the last checkpoint in our pipeline.
- We manually performed the role of a workflow engine (managing data handoff between containers).

```bash
# Create the PVC specified by your config
kubectl apply -f pvc.yaml

# Run job 1
kubectl apply -f job-fetch.yaml

# Run job 2
kubectl apply -f job-process.yaml

# Delete the job (cleanup)
kubectl delete jobs samtools-fetch-job samtools-process-job
```

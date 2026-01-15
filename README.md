# Talos Linux GitOps-like Deployment

This project provides a modular, declarative way to manage Talos Linux clusters using a patch-based configuration engine. It separates core configuration logic from environment-specific data (IPs, hostnames, etc.), providing a streamlined rendering and deployment workflow regardless of where your nodes are running.

## Project Structure

```text
.
├── render.sh                 # Main rendering engine
├── patches/                  # Your active configuration (version controlled)
│   └── envs/
│       └── <env_name>/
│           ├── cluster.env   # Environment variables
│           ├── common.yaml   # Shared environmental patches
│           ├── cluster-addons/# Optional CNI/Addon configurations
│           │   └── cilium-values.yaml
│           ├── control_planes/
│           └── workers/
├── examples/                 # Blueprints for different layouts
├── talos_base_config/        # Generated client configs (ignored)
├── rendered_configs/         # Final rendered node configs (ignored)
└── secrets/                  # Cluster secrets (ignored)
```

## Prerequisites

Before running the scripts, ensure your local environment is prepared:

1. **Required Tooling**: `talosctl`, `kubectl`, `helm`.
2. **Infrastructure**: Your nodes (VMs, bare-metal, etc.) must be running and accessible via network.
3. **Networking**: Static IPs assigned outside your DHCP range.

### Platform Specific Guides
For instructions on how to prepare your nodes on specific platforms, see:
- [KVM / Libvirt Guide](./docs/hypervisor-guides/kvm-guide.md)

## Documentation
For more in-depth information about the architecture and project history:
- [Architecture Analysis](./docs/analysis.md)
- [Legacy README (v1)](./docs/README-V1.md)

---

## Workflow

### 1. Initialize Secrets
```bash
talosctl gen secrets -o ./secrets/secrets.yaml
```

### 2. Setup Configuration
Copy an example layout to your patches directory:
```bash
# Example: Declarative Multi-Env
cp -r examples/declarative-multi-env/* ./patches/
```

### 3. Render Configurations
Generate the final Talos configs and the deployment helper:
```bash
./render.sh <env_name>  # e.g., ./render.sh prod
```

### 4. Deploy
Apply the configurations using the generated script:
```bash
./rendered_configs/<env_name>/apply.sh
```

### 5. Bootstrap
Once the nodes are up, run the bootstrap command printed by `render.sh`:
```bash
talosctl bootstrap --nodes <CP_IP>
```

---

## Architecture Logic

```text
+---------------------+
|   render.sh (Engine)| <-----------------+
+---------------------+                   |
          |                               |
          v                               |
+---------------------------------+  +----------------------+
| patches/ (Source of Truth)      |  | secrets/ secrets.yaml|
| |_ envs/                        |  +----------------------+
|    |_ <env>/                    |           |
|       |_ cluster.env (Identity) |<----------+
|       |_ common.yaml (Shared)   |
|       |_ cluster-addons/        |
|          |_ cilium-values.yaml  |
|       |_ control_planes/        |
|       |_ workers/               |
+---------------------------------+
          |
          v
+---------------------------------+
| rendered_configs/ (Artifacts)   |
| |_ <env>/                       |
|    |_ apply.sh (Automated)      |
|    |_ controlplane-cp1.yaml     |
|    |_ worker-worker1.yaml       |
+---------------------------------+
```

---

## Post-Installation

### 1. Identify your CNI Solution
While this project provides a default configuration for **Cilium**, the architecture is CNI-agnostic. You can deploy any CNI (Flannel, Calico, etc.) by providing your own values files.

### 2. Install Cilium (Default Recommendation)
The default `cilium-values.yaml` included in the examples makes several high-performance architectural choices:
- **Kube-Proxy Replacement**: For better performance and simpler Talos networking.
- **L2 Announcements**: Enables BGP-less LoadBalancer IP management in physical/KVM environments.
- **Built-in Ingress**: Activates the Cilium Ingress Controller by default.

To install using the environment-specific values:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  -f patches/envs/<env_name>/cluster-addons/cilium-values.yaml
```

## Tips

- **Clean**: Use `./render.sh clean <env_name>` to remove sensitive rendered files when done.
- **No SSH**: Use `talosctl dashboard -n <IP>` to monitor nodes.
- **Bootstrap Rule**: Only run `bootstrap` on **one** control plane node.

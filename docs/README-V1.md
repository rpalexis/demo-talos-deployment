## Prerequisites

Before running the scripts, ensure your local environment and hypervisor are prepared:

### 1. Required Tooling
* **[talosctl](https://www.talos.dev/latest/introduction/getting-started/#install-talosctl)**: The official CLI tool to interact with the Talos API.
* **virsh / libvirt**: The standard toolkit for managing KVM virtual machines.
* **kubectl**: The Kubernetes CLI to manage your cluster once it is operational.
* **helm-cli**: To deploy helm charts in the cluster. Here cilium

### 2. KVM / Hypervisor Setup
* **Network Bridge**: A working Linux bridge (e.g., `virbr0`) that allows the VMs to communicate with each other and the gateway.
* **Talos ISO Image**: Download the `metal-amd64.iso` from the [Talos Releases](https://github.com/siderolabs/talos/releases).
* **Hardware Resources**:
    * **Control Plane Nodes**: Minimum 2 vCPUs and 2GB RAM.
    * **Worker Nodes**: Minimum 2 vCPUs and 2GB RAM.

### 3. Networking Requirements
* **Static IPs**: Ensure the IPs you assign in your `patches/` are outside your DHCP range to avoid conflicts.
* **Gateway**: Your patches must point to the correct Gateway IP of your KVM bridge (typically the `.1` address of the subnet).

---

### A Note on "Metal" Mode
Even though we are running inside Virtual Machines, this project uses the **Metal** platform logic. This allows us to manually define the disk layout and network configuration exactly as if we were installing on physical hardware, providing the most "genuine" DevOps learning experience.



### HOW to build on patches

```shell
# Create the secrets.yaml for the cluster
talosctl gen secrets -o ./secrets/secrets.yaml

# Copy one of examples as follow
cp -r examples/EXAMPLE/* ./patches/

# Then generate the final configs from the patches
./render.sh

# Then execute the generated apply script for your environment
./rendered_configs/dev/apply.sh

# Finally, follow the notes for bootstrapping

# After generating the Kubeconfig you need to install cilium.
helm repo add cilium https://helm.cilium.io/

helm repo update

helm upgrade --install cilium cilium/cilium   --namespace kube-system -f cilium-values.yaml
## Remember for this demo kube-proxy has been disabled

```


## Example :  Single Node configuration

```
# Then set the nodes variables (this is because KVM was used | check how to do it with you hypervisor)
export CP_IP=$(virsh domifaddr  NAME_OF_CONTROL_PLANE_NODE | egrep '/' | awk '{print $4}' | cut -d/ -f1)
export NODE_IP=$(virsh domifaddr NAME_OF_WORKER_NODE | egrep '/' | awk '{print $4}' | cut -d/ -f1)

# Set the TALOSCONFIG file
export TALOSCONFIG=./talos_base_config/talosconfig

# Set the endpoints and node
talosctl config endpoint $CP_IP
talosctl config node $NODE_IP

# Apply the configs on the nodes
talosctl apply-config --insecure --nodes $CP_IP --file rendered_configs/controlplane--FILE.yaml
talosctl apply-config --insecure --nodes $NODE_IP --file rendered_configs/worker--FILE.yaml


# Your nodes may restart |  Wait a bit then || If not do
talosctl bootstrap --nodes $CP_IP


# Wait a bit again a get the kubeconfig files

talosctl kubeconfig -n $CP_IP ./talos_base_config/kubeconfig.yaml
```


## Example :  HA Cluster configuration


### Tips for this demo

- **Maintenance Mode:** If `talosctl` fails to apply, check the KVM console. Talos might be in 'Maintenance Mode' waiting for a valid configuration.
- **The Bootstrap Rule:** Even in the HA example, notice we only run `bootstrap` on **one** node (`CP_IP_1`). Never run it on all three.
- **No SSH:** Remember, you cannot SSH into these nodes. Use `talosctl dashboard -n <IP>` to see what is happening inside the engine.

```
# Then set the nodes variables (here KVM was used 
# | check how to do it with you hypervisor 
# | or just use your Host IP if physical nodes are used)
# NB: In KVM, you may have to wait before IPs can be available.
export CP_IP_1=$(virsh domifaddr  NAME_OF_CONTROL_PLANE_NODE_1 | egrep '/' | awk '{print $4}' | cut -d/ -f1)
export CP_IP_2=$(virsh domifaddr  NAME_OF_CONTROL_PLANE_NODE_2 | egrep '/' | awk '{print $4}' | cut -d/ -f1)
export CP_IP_3=$(virsh domifaddr  NAME_OF_CONTROL_PLANE_NODE_3 | egrep '/' | awk '{print $4}' | cut -d/ -f1)
export NODE_IP_1=$(virsh domifaddr NAME_OF_WORKER_NODE_1 | egrep '/' | awk '{print $4}' | cut -d/ -f1)

# Set the TALOSCONFIG file
export TALOSCONFIG=./talos_base_config/talosconfig

# Set the endpoints and node
talosctl config endpoint $CP_IP_1 CP_IP_2 CP_IP_3
talosctl config node $NODE_IP_1 # if more than one worker node NODE_IP_2 NODE_IP_x NODE_IP_y

# Apply the configs on the nodes
talosctl apply-config --insecure --nodes $CP_IP_1 --file rendered_configs/controlplane1.yaml
talosctl apply-config --insecure --nodes $CP_IP_2 --file rendered_configs/controlplane2.yaml
talosctl apply-config --insecure --nodes $CP_IP_3 --file rendered_configs/controlplane3.yaml
talosctl apply-config --insecure --nodes $NODE_IP_1 --file rendered_configs/worker1.yaml


# Your nodes may restart |  Wait a bit then || If not do
talosctl bootstrap --nodes $CP_IP_1


# Wait a bit again a get the kubeconfig files

talosctl kubeconfig -n $CP_IP_1 ./talos_base_config/kubeconfig.yaml
```
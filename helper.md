
# ControlPlanes
sudo virt-install \
  --virt-type kvm \
  --name talos-control-plane-node-1 \
  --ram 4096 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/talos-control-plane-node-1-disk.qcow2,bus=virtio,size=20,format=qcow2 \
  --cdrom /var/lib/libvirt/images/metal-amd64.iso \
  --os-variant=linux2022 \
  --network network=full-cluster-net \
  --boot hd,cdrom --noautoconsole

sudo virt-install \
  --virt-type kvm \
  --name talos-control-plane-node-2 \
  --ram 4096 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/talos-control-plane-node-2-disk.qcow2,bus=virtio,size=20,format=qcow2 \
  --cdrom /var/lib/libvirt/images/metal-amd64.iso \
  --os-variant=linux2022 \
  --network network=full-cluster-net \
  --boot hd,cdrom --noautoconsole

sudo virt-install \
  --virt-type kvm \
  --name talos-control-plane-node-3 \
  --ram 4096 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/talos-control-plane-node-3-disk.qcow2,bus=virtio,size=20,format=qcow2 \
  --cdrom /var/lib/libvirt/images/metal-amd64.iso \
  --os-variant=linux2022 \
  --network network=full-cluster-net \
  --boot hd,cdrom --noautoconsole
#---
# Worker Node
sudo virt-install \
  --virt-type kvm \
  --name talos-worker-node-1 \
  --ram 4096 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/talos-worker-node-1-disk.qcow2,bus=virtio,size=20,format=qcow2 \
  --cdrom /var/lib/libvirt/images/metal-amd64-1.iso \
  --os-variant=linux2022 \
  --network network=full-cluster-net \
  --boot hd,cdrom --noautoconsole

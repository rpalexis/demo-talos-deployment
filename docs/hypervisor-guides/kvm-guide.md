# Creation of a KVM network for the new cluster
```
cat > full-cluster-net.xml <<EOF
<network>
  <name>full-cluster-net</name>
  <bridge name="talos-bridge" stp="on" delay="0"/>
  <forward mode='nat'>
    <nat/>
  </forward>
  <ip address="192.168.215.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.215.1" end="192.168.215.254"/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define full-cluster-net.xml
virsh net-start full-cluster-net
virsh net-autostart full-cluster-net
```


# ControlPlanes
```
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
```

```
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
```

```
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
```

```
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
```
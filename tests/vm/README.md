# Fedora 44 VM tests

End-to-end test of the MuhOS session: GDM logs a user into "MuhOS
(Hyprland)", and the checks verify the session, systemd units, shell
process and per-user files, then take a screenshot and an idle resource
sample.

Runs unprivileged with plain QEMU/KVM (no libvirt); only SSH is forwarded,
to `127.0.0.1:2222`. Needs `qemu-kvm qemu-img guestfs-tools` on the host.

```sh
vm=~/VMs/muhos-test
# Official image; verify the signed CHECKSUM file before use.
curl -LO https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2

tests/vm/build-image base Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2 $vm/vm   # GDM + Hyprland (slow, once)
tests/vm/build-image install $vm/rpms $vm/vm   # muhos, quickshell, matugen RPMs
tests/vm/run start $vm/vm
tests/vm/check $vm/vm 60                      # exit status = failed checks
tests/vm/run stop $vm/vm
```

Keep a copy of the disk after `base` to reinstall new RPMs without repeating
the package download.

The test VM logs in automatically and has password `muhos`; both settings
exist only inside the VM image.

Limits: the guest renders in software (virtio-vga, llvmpipe), so CPU and
memory numbers are only comparable with other runs of this same setup, not
with real hardware. The first login shows the welcome screen; create
`~/.local/state/serpantinum/first_launch.done` in the guest and restart
`muhos-shell.service` to measure the desktop instead.

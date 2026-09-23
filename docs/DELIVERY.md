# USB delivery

Build and burn the appliance on the Ryzen/NVIDIA target host. The ISO stays
on that host throughout this workflow; do not copy it through the Mac.

## Build

From the repository checkout on the Ryzen `x86_64-linux` host:

```sh
nix build .#iso
```

Confirm that the build produced exactly one ISO before selecting a USB device:

```sh
find result -maxdepth 1 -type f -name '*.iso' -print
```

## Identify the USB device

Insert the USB drive and identify its whole-disk device. Use a device listing,
not a guessed name:

```sh
lsblk -o NAME,PATH,MODEL,SIZE,TYPE,MOUNTPOINTS
```

The target must be the USB drive's whole disk, such as `/dev/sdX` or
`/dev/nvme1n1`, not a partition such as `/dev/sdX1`. Check the size and model
carefully. Writing the wrong device destroys its contents.

Unmount any partitions on the USB drive, then replace `/dev/sdX` below with the
verified whole-disk path:

```sh
sudo umount /dev/sdX1
```

If the drive has more partitions, unmount each mounted partition. Do not run
the burn command until the device path has been independently checked.

## Burn and verify

Use the ISO directly from `result/` on the Ryzen host. The shell glob should
match the single ISO confirmed above:

```sh
sudo dd if=result/*.iso of=/dev/sdX bs=16M status=progress conv=fsync
sync
```

After `dd` completes, unplug and reconnect the USB drive, or ask the kernel
to reread its partition table, then inspect it:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
```

The USB is now the boot medium for the same Ryzen box. Boot from it on that
host and follow the boot smoke checks in the specification. This workflow
does not upload an ISO to GitHub or produce a release artifact.

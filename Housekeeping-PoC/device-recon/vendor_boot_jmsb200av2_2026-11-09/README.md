# JMSB200Av2 fastbootd Ethernet reconnaissance

Read-only reconnaissance collected 2026-11-09 from the ADB-connected STB. No reboot, U-Boot change, or partition write was performed during this collection.

## Captured images

- `vendor_boot_a.img` — 25,165,824 bytes; SHA-256 `da3c1cda9d254cdce2e7c314569e64898767fc5f520dd1c60ae3383fac0c5940`.
- `../../boot.img` (the existing Stage-2 extraction) matches the live `/dev/block/by-name/boot_a` SHA-256: `784d3651f43e47a856d6ff49394194e49380e7c984678ca2d404491fe55a25a8`.

The live slot was `_a`. The temporary device-side copy `/data/local/tmp/vendor_boot_a.img` was removed after collection. The original partition was only read.

## Evidence in this build

- `vendor_boot_a.img` is a vendor boot v3 image. Its vendor ramdisk contains `dwmac-dwc-qos-eth.ko`, `dwmac-meson8b.ko`, `stmmac.ko`, and related Ethernet modules.
- The extracted `boot_a` ramdisk contains `/system/bin/fastbootd` and `/system/bin/recovery`.
- `strings` on `system/bin/fastbootd` contains `fastbootd.protocol` and TCP transport identifiers, including `ClientTcpTransport`.
- `system/lib/librecovery_ui.so` exports `EthernetRecoveryUI` methods and contains the UI text `IPv6 link-local address -`.
- `init.recovery.amlogic.rc` and `system/etc/init/hw/init.rc` include USB FunctionFS fastboot setup. The ordinary USB setup does not rule out Ethernet: the Ethernet recovery UI can select TCP for fastbootd separately.
- Android-side `/vendor/etc/init`, `/system/etc/init`, and fstab inspection showed no explicit Ethernet-fastboot text. The relevant behavior is compiled into the recovery/fastbootd binaries and UI library, rather than necessarily appearing as an init/fstab stanza.

## Assessment

This is strong build-level evidence that the device image contains AOSP fastbootd-over-Ethernet support, likely using `eth0`, TCP, and an IPv6 link-local address. AOSP's Ethernet recovery UI sets `fastbootd.protocol=tcp`, brings up `eth0`, and displays its link-local IPv6 address; AOSP fastbootd selects the TCP transport when that property is `tcp`.

This is not yet runtime proof that Jio's recovery actually selects the Ethernet UI, that the link-local address is usable on this direct PC link, or that all fastboot commands are supported. The earlier scan after `adb reboot bootloader` tested U-Boot fastboot, not Android userspace fastbootd, so its lack of an IPv4 response does not disprove this fastbootd result.

## Source references

- AOSP change introducing `librecovery_ui_ethernet` and describing the BoardConfig selection: <https://android.googlesource.com/platform/bootable/recovery/%2B/4d0df88%5E%21/>
- AOSP Ethernet device implementation: <https://android.googlesource.com/platform/bootable/recovery/%2B/refs/heads/master/recovery_ui/ethernet_device.cpp>
- AOSP fastbootd chooses TCP when `fastbootd.protocol=tcp`: <https://android.googlesource.com/platform/system/core/%2B/master/fastboot/device/fastboot_device.cpp>
- AOSP host fastboot network address syntax/default TCP port: <https://android.googlesource.com/platform/system/core/%2B/master/fastboot/fastboot.cpp>

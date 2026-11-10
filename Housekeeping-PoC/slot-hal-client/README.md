# HIDL Boot Control client (Jio STB recon)

This small Java `app_process` client probes the device's HIDL
`android.hardware.boot@1.0::IBootControl` implementation. Its default mode is
read-only: it queries the slot count, current slot, and slot flags. The explicit
`set-active <slot> --confirm` mode calls the HAL's `setActiveBootSlot`; that
changes A/B metadata in `/misc` and does not reboot.

Build on the host with `./build.sh`. The generated JAR is `build/slot-hal-client.jar`.
Push/run it through the existing RootShell2 helper as described in the session.

Example invocation through the repository's RootShell2 helper:

```sh
CLASSPATH=/data/local/tmp/slot-hal-client.jar app_process / BootControlProbe
CLASSPATH=/data/local/tmp/slot-hal-client.jar app_process / BootControlProbe set-active 1 --confirm
```

On the JMSB200Av2 tested here, getter transactions returned two slots and the
setter changed the BCB priorities (A 15→14; B 14→15, with B's tries set to 6).
The first setter client version misread the HIDL `CommandResult` and crashed
after the HAL call; the current source reads the generated HIDL fields. The
verified BCB state is not proof that B will boot or that fallback behavior is
safe. Do not reboot without a recovery path and a verified display/input setup.

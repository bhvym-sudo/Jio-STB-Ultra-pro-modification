import java.lang.reflect.Constructor;
import java.lang.reflect.Method;

/** Probe Android's HIDL BootControl v1.0 service. */
public final class BootControlProbe {
    private static final String IFACE = "android.hardware.boot@1.0::IBootControl";
    private static final int GET_NUMBER_SLOTS = 1;
    private static final int GET_CURRENT_SLOT = 2;
    private static final int SET_ACTIVE_BOOT_SLOT = 4;
    private static final int IS_SLOT_BOOTABLE = 6;
    private static final int IS_SLOT_SUCCESSFUL = 7;

    private static Object invoke(Object target, String name, Class<?>[] types,
                                 Object... args) throws Exception {
        Method method = target.getClass().getMethod(name, types);
        return method.invoke(target, args);
    }

    private static int callInt(Object remote, int code, Integer argument)
            throws Exception {
        Class<?> parcelClass = Class.forName("android.os.HwParcel");
        Constructor<?> ctor = parcelClass.getConstructor();
        Object request = ctor.newInstance();
        Object reply = ctor.newInstance();
        try {
            invoke(request, "writeInterfaceToken",
                    new Class<?>[]{String.class}, IFACE);
            if (argument != null) {
                invoke(request, "writeInt32",
                        new Class<?>[]{int.class}, argument.intValue());
            }
            Class<?> binderClass = Class.forName("android.os.IHwBinder");
            binderClass.getMethod("transact",
                    int.class, parcelClass, parcelClass, int.class)
                    .invoke(remote, code, request, reply, 0);
            invoke(reply, "verifySuccess", new Class<?>[]{});
            invoke(request, "releaseTemporaryStorage", new Class<?>[]{});
            return ((Integer) invoke(reply, "readInt32", new Class<?>[]{})).intValue();
        } finally {
            try { invoke(reply, "release", new Class<?>[]{}); } catch (Exception ignored) {}
            try { invoke(request, "release", new Class<?>[]{}); } catch (Exception ignored) {}
        }
    }

    private static void setActive(Object remote, int slot) throws Exception {
        Class<?> parcelClass = Class.forName("android.os.HwParcel");
        Object request = parcelClass.getConstructor().newInstance();
        Object reply = parcelClass.getConstructor().newInstance();
        try {
            invoke(request, "writeInterfaceToken", new Class<?>[]{String.class}, IFACE);
            invoke(request, "writeInt32", new Class<?>[]{int.class}, slot);
            Class<?> binderClass = Class.forName("android.os.IHwBinder");
            binderClass.getMethod("transact", int.class, parcelClass, parcelClass, int.class)
                    .invoke(remote, SET_ACTIVE_BOOT_SLOT, request, reply, 0);
            invoke(reply, "verifySuccess", new Class<?>[]{});
            invoke(request, "releaseTemporaryStorage", new Class<?>[]{});

            // Generated HIDL Java stubs serialize CommandResult as its fields.
            boolean success = ((Boolean) invoke(reply, "readBool", new Class<?>[]{}))
                    .booleanValue();
            String error = (String) invoke(reply, "readString", new Class<?>[]{});
            System.out.println("set_active_transport=ok");
            System.out.println("set_active_command_success=" + success);
            System.out.println("set_active_error=" + error);
            if (!success) throw new IllegalStateException("HAL rejected setActiveBootSlot: " + error);
        } finally {
            try { invoke(reply, "release", new Class<?>[]{}); } catch (Exception ignored) {}
            try { invoke(request, "release", new Class<?>[]{}); } catch (Exception ignored) {}
        }
    }

    public static void main(String[] args) throws Exception {
        Class<?> binderClass = Class.forName("android.os.HwBinder");
        Object remote = binderClass.getMethod("getService", String.class, String.class)
                .invoke(null, IFACE, "default");
        if (remote == null) throw new IllegalStateException("BootControl HIDL service unavailable");

        int slots = callInt(remote, GET_NUMBER_SLOTS, null);
        int current = callInt(remote, GET_CURRENT_SLOT, null);
        System.out.println("slot_count=" + slots);
        System.out.println("current_slot=" + current);
        if (slots < 1 || slots > 8 || current < 0 || current >= slots) {
            throw new IllegalStateException("HAL returned out-of-range slot data");
        }
        for (int slot = 0; slot < slots; slot++) {
            int bootable = callInt(remote, IS_SLOT_BOOTABLE, Integer.valueOf(slot));
            int successful = callInt(remote, IS_SLOT_SUCCESSFUL, Integer.valueOf(slot));
            System.out.println("slot_" + slot + "_bootable_enum=" + bootable);
            System.out.println("slot_" + slot + "_successful_enum=" + successful);
        }

        if (args.length > 0) {
            if (args.length != 3 || !"set-active".equals(args[0]) || !"--confirm".equals(args[2])) {
                throw new IllegalArgumentException("Usage: BootControlProbe [set-active <slot> --confirm]");
            }
            int target = Integer.parseInt(args[1]);
            if (slots != 2 || current != 0 || target != 1 ||
                    callInt(remote, IS_SLOT_BOOTABLE, Integer.valueOf(target)) != 1) {
                throw new IllegalStateException("Refusing: expected A active and B present/bootable");
            }
            setActive(remote, target);
        }
    }
}

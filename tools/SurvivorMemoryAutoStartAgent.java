import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaTableIterator;

/** Test-only helper that releases B42's normal click-to-start loading gate. */
public final class SurvivorMemoryAutoStartAgent {
    private SurvivorMemoryAutoStartAgent() {}

    public static void premain(String arguments, Instrumentation instrumentation) {
        Thread worker = new Thread(SurvivorMemoryAutoStartAgent::waitForLoadingGate,
            "SM-AutoStart-Agent");
        worker.setDaemon(true);
        worker.start();
    }

    private static void waitForLoadingGate() {
        long deadline = System.currentTimeMillis() + 150_000L;
        while (System.currentTimeMillis() < deadline) {
            try {
                Class<?> gameWindowClass = Class.forName("zombie.GameWindow");
                Object stateMachine = gameWindowClass.getField("states").get(null);
                if (stateMachine != null) {
                    Object current = stateMachine.getClass().getField("current").get(stateMachine);
                    if (current != null && current.getClass().getName()
                            .equals("zombie.gameStates.GameLoadingState")) {
                        Class<?> loadingClass = current.getClass();
                        Field done = privateField(loadingClass, "done");
                        Field playerCreated = privateField(loadingClass, "playerCreated");
                        Field showedClick = privateField(loadingClass, "showedClickToSkip");
                        if (done.getBoolean(null) && playerCreated.getBoolean(null)
                                && showedClick.getBoolean(null)) {
                            privateField(loadingClass, "forceDone").setBoolean(current, true);
                            System.out.println("[SurvivorMemory] SMOKE agent released loading gate");
                            if (Boolean.getBoolean("sm.reload")) validateReloadedPlayer();
                            return;
                        }
                    }
                }
            } catch (ClassNotFoundException ignored) {
                // Game classes are not loaded yet.
            } catch (ReflectiveOperationException | RuntimeException error) {
                System.err.println("[SurvivorMemory] SMOKE agent error=" + error);
                return;
            }
            try {
                Thread.sleep(100L);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            }
        }
        System.err.println("[SurvivorMemory] SMOKE agent timeout");
    }

    private static void validateReloadedPlayer() {
        try {
            Thread.sleep(1500L);
            Object player = Class.forName("zombie.characters.IsoPlayer")
                .getMethod("getInstance").invoke(null);
            Object modData = player.getClass().getMethod("getModData").invoke(player);
            Object root = rawget(modData, "SurvivorMemory");
            Object schema = rawget(root, "schemaVersion");
            Object buildings = rawget(root, "buildings");
            Object memory = firstValue(buildings);
            Object vehicleMemories = rawget(root, "vehicleMemories");
            boolean pass = ((Number) schema).intValue() == 5
                && count(buildings) == 1
                && count(vehicleMemories) == 1
                && ((Number) rawget(memory, "visitCount")).intValue() == 2
                && count(rawget(memory, "roomsKnown")) == 2
                && count(rawget(memory, "containersInspected")) == 2
                && ((Number) rawget(root, "revision")).intValue() > 0
                && "HOUSE".equals(rawget(memory, "locationKind"))
                && "HOME".equals(rawget(memory, "placeDesignation"))
                && rawget(memory, "emotionalMemory") != null
                && rawget(rawget(memory, "emotionalMemory"), "observedAt") != null
                && rawget(rawget(memory, "emotionalMemory"), "lastReactionAt") != null
                && ((Number) rawget(memory, "firstVisited")).doubleValue()
                    < ((Number) rawget(memory, "lastVisited")).doubleValue()
                && "PARTIALLY_SEARCHED".equals(rawget(memory, "status"));
            System.out.println("[SurvivorMemory] RELOAD RESULT status="
                + (pass ? "PASS" : "FAIL") + " failures=" + (pass ? "" : "persisted_values"));
        } catch (Throwable error) {
            System.out.println("[SurvivorMemory] RELOAD RESULT status=FAIL failures="
                + error.getClass().getSimpleName());
        }
    }

    private static Object rawget(Object table, Object key) {
        if (table == null) return null;
        return ((KahluaTable) table).rawget(key);
    }

    private static Object firstValue(Object table) {
        KahluaTableIterator iterator = ((KahluaTable) table).iterator();
        if (!iterator.advance()) return null;
        return iterator.getValue();
    }

    private static int count(Object table) {
        int count = 0;
        KahluaTableIterator iterator = ((KahluaTable) table).iterator();
        while (iterator.advance()) count++;
        return count;
    }

    private static Field privateField(Class<?> type, String name)
            throws ReflectiveOperationException {
        Field field = type.getDeclaredField(name);
        field.setAccessible(true);
        return field;
    }
}

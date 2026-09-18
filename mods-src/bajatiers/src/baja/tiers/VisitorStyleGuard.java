package baja.tiers;

import java.lang.reflect.Method;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.Logger;

import com.mojang.logging.LogUtils;

import net.minecraft.world.entity.Entity;

/**
 * Bookkeeping for {@link baja.tiers.mixin.VisitorStyleGuardMixin} (lives outside the mixin package:
 * Mixin refuses to load ordinary classes from there). Common code only -- no client imports, the
 * mixin is applied on both sides so a dedicated-server boot can prove the injection point matches.
 */
public final class VisitorStyleGuard {

    private static final Logger LOGGER = LogUtils.getLogger();
    private static final String TARGET = "com.minecolonies.core.entity.visitor.VisitorCitizen";
    private static final String HANDLER = "bajatiers$skipNullStyle";
    private static final AtomicInteger SKIPPED = new AtomicInteger();

    private VisitorStyleGuard() { }

    /** Called by the mixin each time it swallows a null style: that is one client crash that did not happen. */
    public static void noteSkip(Entity visitor) {
        int n = SKIPPED.incrementAndGet();
        // first few in full, then every 100th: a view that stays style-less would otherwise log once a second
        if (n <= 3 || n % 100 == 0) {
            LOGGER.warn("VisitorStyleGuard: dropped a null texture style for visitor entity {} at {} (thread {}, #{} this session) -- without the guard this was a 'Rendering entity in world' crash.",
                visitor.getId(), visitor.blockPosition().toShortString(), Thread.currentThread().getName(), n);
        }
    }

    /**
     * One line per launch: did the redirect actually merge into VisitorCitizen? The mixin is
     * deliberately non-required, so a silent no-op is possible after a MineColonies update and this
     * line is the only thing that tells. Loads the class WITHOUT initialising it (the transformer
     * runs at define time), so no static init is pulled forward.
     */
    static void report() {
        try {
            Class<?> c = Class.forName(TARGET, false, VisitorStyleGuard.class.getClassLoader());
            for (Method m : c.getDeclaredMethods()) {
                // Mixin renames injector handlers (redirect$<hash>$bajatiers$skipNullStyle): match on CONTAINS
                if (m.getName().contains(HANDLER)) {
                    LOGGER.info("VisitorStyleGuard=APPLIED (MineColonies visitor null-style client crash guarded)");
                    return;
                }
            }
            LOGGER.warn("VisitorStyleGuard=NOT APPLIED -- MineColonies is present but the redirect did not merge (MineColonies updated?). Visitors can crash clients again; see mods-src/bajatiers.");
        } catch (ClassNotFoundException e) {
            LOGGER.info("VisitorStyleGuard=SKIPPED (MineColonies not installed)");
        } catch (Throwable t) {
            LOGGER.warn("VisitorStyleGuard=UNKNOWN (could not inspect {}: {})", TARGET, t.toString());
        }
    }
}

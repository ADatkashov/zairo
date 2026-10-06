package com.zairo.factory.workforce;

import java.util.function.Supplier;

/**
 * Marks "the system is picking the person" for the current thread, so the guard doesn't refuse a booking on a
 * business that has turned off choosing a specific worker: the customer didn't choose, the system did.
 */
final class WorkerAssignmentContext {

    private static final ThreadLocal<Boolean> ASSIGNING = ThreadLocal.withInitial(() -> false);

    private WorkerAssignmentContext() {
    }

    static boolean isAssigning() {
        return ASSIGNING.get();
    }

    static <T> T runAssigning(Supplier<T> action) {
        boolean previous = ASSIGNING.get();
        ASSIGNING.set(true);
        try {
            return action.get();
        } finally {
            ASSIGNING.set(previous);
        }
    }
}

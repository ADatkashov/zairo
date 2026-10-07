package com.zairo.factory.workforce;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * One transaction-scoped lock per human (or per typed-in worker with no account): every place that decides "is this
 * person free then?" takes it first, so two requests racing for the same minute are serialized and the second one
 * sees the first one's booking.
 */
@Component
class PersonLock {

    private final JdbcClient jdbc;

    PersonLock(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    void acquire(Worker worker) {
        Object key = worker.userId() != null ? worker.userId() : worker.id();
        jdbc.sql("select pg_advisory_xact_lock(hashtext(:key))").param("key", "worker-person:" + key)
                .query((rs, n) -> 1).list();
    }
}

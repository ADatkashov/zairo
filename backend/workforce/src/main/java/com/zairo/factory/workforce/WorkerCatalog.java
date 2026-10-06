package com.zairo.factory.workforce;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * Reads and (for re-linking a booking) writes the four worker directories as one. The four tables are
 * deliberately identical in shape (id, provider_id, user_id, display_name, photo_url, is_active; a service-link
 * table; a booking-link table), so one table of names is all it takes — none of the directory modules has to know
 * about this one, and none is changed.
 *
 * <p>Table and column names below are constants, never user input, so building the SQL with them is safe.
 */
@Component
public class WorkerCatalog {

    /** The table names of one directory. */
    private record Spec(WorkerKind kind, String table, String serviceTable, String serviceWorkerCol,
            String bookingTable, String bookingWorkerCol) {
    }

    private static final List<Spec> SPECS = List.of(
            new Spec(WorkerKind.STAFF, "staff", "staff_service", "staff_id", "staff_booking", "staff_id"),
            new Spec(WorkerKind.MASTER, "beauty_master", "beauty_master_service", "master_id",
                    "beauty_master_booking", "master_id"),
            new Spec(WorkerKind.MECHANIC, "auto_mechanic", "auto_mechanic_service", "mechanic_id", "auto_booking",
                    "mechanic_id"),
            new Spec(WorkerKind.CLEANER, "cleaning_cleaner", "cleaning_cleaner_service", "cleaner_id",
                    "cleaning_booking", "cleaner_id"));

    private static final String COLUMNS = "id, provider_id, user_id, display_name, photo_url, is_active";

    private final JdbcClient jdbc;

    public WorkerCatalog(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Worker> find(UUID workerId) {
        for (Spec spec : SPECS) {
            Optional<Worker> found = jdbc.sql("select " + COLUMNS + " from " + spec.table() + " where id = :id")
                    .param("id", workerId).query((rs, n) -> map(spec.kind(), rs)).optional();
            if (found.isPresent()) {
                return found;
            }
        }
        return Optional.empty();
    }

    /** Every place a person works, in any directory. */
    public List<Worker> findByUserId(UUID userId) {
        List<Worker> result = new ArrayList<>();
        for (Spec spec : SPECS) {
            result.addAll(jdbc.sql("select " + COLUMNS + " from " + spec.table() + " where user_id = :userId")
                    .param("userId", userId).query((rs, n) -> map(spec.kind(), rs)).list());
        }
        return result;
    }

    public List<Worker> findByProvider(UUID providerId) {
        List<Worker> result = new ArrayList<>();
        for (Spec spec : SPECS) {
            result.addAll(jdbc.sql("select " + COLUMNS + " from " + spec.table()
                    + " where provider_id = :providerId order by display_name")
                    .param("providerId", providerId).query((rs, n) -> map(spec.kind(), rs)).list());
        }
        return result;
    }

    /** Active workers of a business who perform the given service. */
    public List<Worker> findOfferingService(UUID providerId, UUID serviceId) {
        List<Worker> result = new ArrayList<>();
        for (Spec spec : SPECS) {
            result.addAll(jdbc.sql("select w.id, w.provider_id, w.user_id, w.display_name, w.photo_url, w.is_active"
                    + " from " + spec.table() + " w join " + spec.serviceTable() + " l on l." + spec.serviceWorkerCol()
                    + " = w.id where w.provider_id = :providerId and l.service_id = :serviceId and w.is_active")
                    .param("providerId", providerId).param("serviceId", serviceId)
                    .query((rs, n) -> map(spec.kind(), rs)).list());
        }
        return result;
    }

    public boolean offersService(Worker worker, UUID serviceId) {
        Spec spec = spec(worker.kind());
        return jdbc.sql("select count(*) from " + spec.serviceTable() + " where " + spec.serviceWorkerCol()
                + " = :worker and service_id = :service").param("worker", worker.id()).param("service", serviceId)
                .query(Long.class).single() > 0;
    }

    /**
     * Every booking that belongs to this worker: ones made through the directory's own booking endpoint (a link
     * row) and ones on a slot generated for them ({@code availability_slot.employee_id}).
     */
    public Set<UUID> bookingIdsOf(Worker worker) {
        Spec spec = spec(worker.kind());
        List<UUID> ids = jdbc.sql("select booking_id from " + spec.bookingTable() + " where " + spec.bookingWorkerCol()
                + " = :id union select b.id from booking b join availability_slot s on s.id = b.availability_slot_id"
                + " where s.employee_id = :id").param("id", worker.id())
                .query((rs, n) -> rs.getObject(1, UUID.class)).list();
        return new LinkedHashSet<>(ids);
    }

    /** Who a booking is with: its directory link row, else the owner of the slot it sits on. */
    public Optional<Worker> workerOfBooking(UUID bookingId) {
        for (Spec spec : SPECS) {
            Optional<UUID> workerId = jdbc.sql("select " + spec.bookingWorkerCol() + " from " + spec.bookingTable()
                    + " where booking_id = :b").param("b", bookingId)
                    .query((rs, n) -> rs.getObject(1, UUID.class)).optional();
            if (workerId.isPresent()) {
                return find(workerId.get());
            }
        }
        Optional<UUID> employee = jdbc.sql("select s.employee_id from booking b join availability_slot s on s.id"
                + " = b.availability_slot_id where b.id = :b and s.employee_id is not null").param("b", bookingId)
                .query((rs, n) -> rs.getObject(1, UUID.class)).optional();
        return employee.flatMap(this::find);
    }

    /** Points an existing booking's directory link at another worker of the same kind. */
    public void relink(Worker newWorker, UUID bookingId) {
        Spec spec = spec(newWorker.kind());
        jdbc.sql("update " + spec.bookingTable() + " set " + spec.bookingWorkerCol() + " = :w where booking_id = :b")
                .param("w", newWorker.id()).param("b", bookingId).update();
    }

    private static Worker map(WorkerKind kind, java.sql.ResultSet rs) throws java.sql.SQLException {
        return new Worker(kind, rs.getObject("id", UUID.class), rs.getObject("provider_id", UUID.class),
                rs.getObject("user_id", UUID.class), rs.getString("display_name"), rs.getString("photo_url"),
                rs.getBoolean("is_active"));
    }

    private static Spec spec(WorkerKind kind) {
        return SPECS.stream().filter(s -> s.kind() == kind).findFirst().orElseThrow();
    }
}

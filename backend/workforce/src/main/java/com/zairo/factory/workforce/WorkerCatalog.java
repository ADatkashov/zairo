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

    /** Everyone who no longer works at their business (deactivated in their directory). */
    public List<Worker> findInactive() {
        List<Worker> result = new ArrayList<>();
        for (Spec spec : SPECS) {
            result.addAll(jdbc.sql("select " + COLUMNS + " from " + spec.table() + " where not is_active")
                    .query((rs, n) -> map(spec.kind(), rs)).list());
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

    /**
     * Points an existing booking's directory link at another worker of the same kind.
     *
     * @return how many link rows were updated (0 when the booking has no link row — it is attributed to its worker
     *         only through the slot it sits on)
     */
    public int relink(Worker newWorker, UUID bookingId) {
        Spec spec = spec(newWorker.kind());
        return jdbc.sql("update " + spec.bookingTable() + " set " + spec.bookingWorkerCol()
                + " = :w where booking_id = :b").param("w", newWorker.id()).param("b", bookingId).update();
    }

    /** Whether the booking has a row in this kind's directory link table. */
    public boolean hasLink(WorkerKind kind, UUID bookingId) {
        Spec spec = spec(kind);
        return jdbc.sql("select count(*) from " + spec.bookingTable() + " where booking_id = :b")
                .param("b", bookingId).query(Long.class).single() > 0;
    }

    /** A worker with the rating that earned a place on the "best masters" list, and where they work. */
    public record Ranked(Worker worker, String providerName, double averageRating, long reviewCount) {
    }

    /** One service a worker performs, for their public page. */
    public record OfferedService(UUID id, String title, int durationMinutes, java.math.BigDecimal price,
            String currency) {
    }

    /** Every booking of the directory's workers: its link row, or the slot the booking sits on. */
    private static String bookingsOfWorkers(Spec spec) {
        return "select " + spec.bookingWorkerCol() + " as worker_id, booking_id from " + spec.bookingTable()
                + " union select s.employee_id as worker_id, b.id as booking_id from booking b join availability_slot s"
                + " on s.id = b.availability_slot_id where s.employee_id is not null";
    }

    /**
     * Active workers of ACTIVE businesses, best average review rating first, across all four directories. A worker
     * needs at least {@code minReviews} reviews so that one lucky 5-star does not outrank a long record. With a
     * {@code city}, only businesses of that city count — plus businesses that have not set a city yet, so that the
     * list is not empty while owners are still filling their profile in.
     */
    public List<Ranked> topRated(int minReviews, int limit, String city) {
        List<Ranked> all = new ArrayList<>();
        for (Spec spec : SPECS) {
            all.addAll(jdbc.sql("select w.id, w.provider_id, w.user_id, w.display_name, w.photo_url, w.is_active,"
                    + " p.name as provider_name, avg(r.rating) as average_rating, count(r.id) as review_count"
                    + " from " + spec.table() + " w join provider p on p.id = w.provider_id join ("
                    + bookingsOfWorkers(spec) + ") wb on wb.worker_id = w.id join review r on r.booking_id"
                    + " = wb.booking_id where w.is_active and p.status = 'ACTIVE'"
                    + " and (cast(:city as varchar) is null or p.city_code is null or p.city_code = :city)"
                    + " group by w.id, w.provider_id, w.user_id, w.display_name, w.photo_url, w.is_active, p.name"
                    + " having count(r.id) >= :min").param("min", minReviews)
                    .param("city", city)
                    .query((rs, n) -> new Ranked(map(spec.kind(), rs), rs.getString("provider_name"),
                            rs.getDouble("average_rating"), rs.getLong("review_count")))
                    .list());
        }
        return all.stream()
                .sorted(java.util.Comparator.comparingDouble(Ranked::averageRating).reversed()
                        .thenComparing(java.util.Comparator.comparingLong(Ranked::reviewCount).reversed())
                        .thenComparing(r -> r.worker().displayName(), String.CASE_INSENSITIVE_ORDER))
                .limit(limit).toList();
    }

    /** This worker's rating alone: {@code reviewCount} 0 when nobody has reviewed them yet. */
    public Ranked ratingOf(Worker worker, String providerName) {
        Spec spec = spec(worker.kind());
        return jdbc.sql("select coalesce(avg(r.rating), 0) as average_rating, count(r.id) as review_count from ("
                + bookingsOfWorkers(spec) + ") wb join review r on r.booking_id = wb.booking_id"
                + " where wb.worker_id = :id").param("id", worker.id())
                .query((rs, n) -> new Ranked(worker, providerName, rs.getDouble("average_rating"),
                        rs.getLong("review_count")))
                .single();
    }

    /** One review left on a booking with this worker; no reviewer identity, it is shown publicly. */
    public record WorkerReview(int rating, String comment, java.time.Instant createdAt, String businessReply) {
    }

    /** The worker's own "about me" text, if they wrote one. */
    public Optional<String> bioOf(Worker worker) {
        Spec spec = spec(worker.kind());
        return jdbc.sql("select bio from " + spec.table() + " where id = :id").param("id", worker.id())
                .query(String.class).optional().filter(b -> !b.isBlank());
    }

    /** The newest reviews on this worker's bookings. */
    public List<WorkerReview> latestReviews(Worker worker, int limit) {
        Spec spec = spec(worker.kind());
        return jdbc.sql("select r.rating, r.comment, r.created_at, r.business_reply from (" + bookingsOfWorkers(spec)
                + ") wb join review r on r.booking_id = wb.booking_id where wb.worker_id = :id"
                + " order by r.created_at desc limit :limit").param("id", worker.id()).param("limit", limit)
                .query((rs, n) -> new WorkerReview(rs.getInt("rating"), rs.getString("comment"),
                        rs.getTimestamp("created_at").toInstant(), rs.getString("business_reply")))
                .list();
    }

    /** The active services this worker performs. */
    public List<OfferedService> servicesOf(Worker worker) {
        Spec spec = spec(worker.kind());
        return jdbc.sql("select sv.id, sv.title, sv.duration_minutes, sv.price, sv.currency from "
                + spec.serviceTable() + " l join service sv on sv.id = l.service_id where l."
                + spec.serviceWorkerCol() + " = :id and sv.is_active order by sv.title")
                .param("id", worker.id())
                .query((rs, n) -> new OfferedService(rs.getObject("id", UUID.class), rs.getString("title"),
                        rs.getInt("duration_minutes"), rs.getBigDecimal("price"), rs.getString("currency")))
                .list();
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

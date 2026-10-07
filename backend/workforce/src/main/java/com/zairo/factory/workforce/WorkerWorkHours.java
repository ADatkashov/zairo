package com.zairo.factory.workforce;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.UUID;

/** One working interval of a worker on one weekday. A day with a lunch break has two of these. */
@Entity
@Table(name = "worker_work_hours")
public class WorkerWorkHours {

    @Id
    private UUID id;

    @Column(name = "worker_id", nullable = false)
    private UUID workerId;

    /** 1 = Monday .. 7 = Sunday ({@link DayOfWeek#getValue()}). */
    @Column(name = "day_of_week", nullable = false)
    private int dayOfWeek;

    @Column(name = "start_time", nullable = false)
    private LocalTime startTime;

    @Column(name = "end_time", nullable = false)
    private LocalTime endTime;

    protected WorkerWorkHours() {
    }

    public WorkerWorkHours(UUID id, UUID workerId, DayOfWeek dayOfWeek, LocalTime startTime, LocalTime endTime) {
        this.id = id;
        this.workerId = workerId;
        this.dayOfWeek = dayOfWeek.getValue();
        this.startTime = startTime;
        this.endTime = endTime;
    }

    public UUID getWorkerId() {
        return workerId;
    }

    public DayOfWeek getDayOfWeek() {
        return DayOfWeek.of(dayOfWeek);
    }

    public LocalTime getStartTime() {
        return startTime;
    }

    public LocalTime getEndTime() {
        return endTime;
    }
}

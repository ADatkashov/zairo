package com.zairo.factory.workforce;

/** Which of the four directories a worker lives in. Worker ids are UUIDs, unique across all four. */
public enum WorkerKind {
    /** Generic staff (the {@code staff} module) — any category without its own directory. */
    STAFF,
    /** A beauty master ({@code vertical-beauty}). */
    MASTER,
    /** An auto mechanic ({@code vertical-auto}). */
    MECHANIC,
    /** A cleaner ({@code vertical-cleaning}). */
    CLEANER
}

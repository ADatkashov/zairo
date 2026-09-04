/**
 * Generic object storage (S3-compatible; MinIO in dev). Uploads go through
 * this module's own endpoints rather than the client talking to MinIO
 * directly — keeps storage credentials server-side and reuses the same
 * CORS setup as every other endpoint, instead of configuring CORS/public
 * read access on the bucket itself. Vertical-agnostic: any module that
 * needs to store a file (portfolio photos today, provider logos or other
 * media later) can depend on this one.
 *
 * Only JPEG/PNG/WebP images are accepted — see DetectedImageType — verified
 * from the file's own bytes on upload, and re-verified from stored
 * metadata on download. Neither the client-supplied filename nor
 * Content-Type is ever trusted for either direction; download's response
 * Content-Type always comes from that same validated allowlist. This
 * closes a stored-XSS path an unrestricted upload+echo would otherwise
 * open (e.g. an HTML/SVG file served back with a browser-executable
 * Content-Type from this module's own origin).
 */
package com.zairo.factory.storage;

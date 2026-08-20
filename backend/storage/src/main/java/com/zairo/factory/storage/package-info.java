/**
 * Generic object storage (S3-compatible; MinIO in dev). Uploads go through
 * this module's own endpoints rather than the client talking to MinIO
 * directly — keeps storage credentials server-side and reuses the same
 * CORS setup as every other endpoint, instead of configuring CORS/public
 * read access on the bucket itself. Vertical-agnostic: any module that
 * needs to store a file (portfolio photos today, provider logos or other
 * media later) can depend on this one.
 */
package com.zairo.factory.storage;

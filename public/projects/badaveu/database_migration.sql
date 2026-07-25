-- ============================================================
-- Més Badalona v3.0 — Database Migration
-- Run this once in phpMyAdmin or via mysql CLI
-- ============================================================

USE mesbadalona;

-- 1. Add views counter
ALTER TABLE incidencias
    ADD COLUMN IF NOT EXISTS views INT DEFAULT 0;

-- 2. Add updated_at with auto-update
ALTER TABLE incidencias
    ADD COLUMN IF NOT EXISTS updated_at DATETIME NULL ON UPDATE CURRENT_TIMESTAMP;

-- 3. Performance indexes
CREATE INDEX IF NOT EXISTS idx_estado     ON incidencias(estado);
CREATE INDEX IF NOT EXISTS idx_categoria  ON incidencias(categoria);
CREATE INDEX IF NOT EXISTS idx_barri      ON incidencias(barri);
CREATE INDEX IF NOT EXISTS idx_created_at ON incidencias(created_at);
CREATE INDEX IF NOT EXISTS idx_lat_lng    ON incidencias(lat, lng);
CREATE INDEX IF NOT EXISTS idx_views      ON incidencias(views);

-- 4. Ensure admins table has access columns
ALTER TABLE admins
    ADD COLUMN IF NOT EXISTS access_type     VARCHAR(50)  DEFAULT 'all',
    ADD COLUMN IF NOT EXISTS district_access VARCHAR(255) DEFAULT 'all';

-- 5. Fix afectacion encoding inconsistencies
UPDATE incidencias
SET afectacion = 'col·lectiva'
WHERE afectacion IN ('colectiva', 'col.lectiva', 'col-lectiva');

-- 6. Backfill views = 0 for existing rows
UPDATE incidencias SET views = 0 WHERE views IS NULL;

-- Verification
SELECT
    COUNT(*)                              AS total_incidents,
    SUM(IF(views IS NULL, 1, 0))          AS null_views,
    SUM(IF(updated_at IS NULL, 1, 0))     AS null_updated_at
FROM incidencias;

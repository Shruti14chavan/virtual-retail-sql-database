-- Week 2 ETL planning examples | MySQL 8.x
-- Educational template: review and adapt before executing in a real environment.
USE VirtualRetailDB;

-- 1. Batch audit log: one row per ETL run.
CREATE TABLE IF NOT EXISTS ETL_BatchLog (
    BatchID BIGINT AUTO_INCREMENT PRIMARY KEY,
    SourceName VARCHAR(100) NOT NULL,
    StartedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CompletedAt DATETIME NULL,
    BatchStatus VARCHAR(20) NOT NULL DEFAULT 'Running',
    ExtractedRows INT NOT NULL DEFAULT 0,
    AcceptedRows INT NOT NULL DEFAULT 0,
    RejectedRows INT NOT NULL DEFAULT 0,
    LoadedRows INT NOT NULL DEFAULT 0,
    WatermarkFrom VARCHAR(100) NULL,
    WatermarkTo VARCHAR(100) NULL,
    ErrorMessage VARCHAR(1000) NULL
);

-- 2. Reject queue: never silently discard invalid source records.
CREATE TABLE IF NOT EXISTS ETL_Rejects (
    RejectID BIGINT AUTO_INCREMENT PRIMARY KEY,
    BatchID BIGINT NOT NULL,
    SourceName VARCHAR(100) NOT NULL,
    SourceRowID VARCHAR(150) NULL,
    ReasonCode VARCHAR(100) NOT NULL,
    ReasonDetail VARCHAR(1000) NULL,
    RejectedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_ETL_Rejects_BatchLog
        FOREIGN KEY (BatchID) REFERENCES ETL_BatchLog(BatchID)
);

-- 3. Raw staging example: preserve source values as strings to profile before conversion.
CREATE TABLE IF NOT EXISTS Stg_RawProducts (
    StagingRowID BIGINT AUTO_INCREMENT PRIMARY KEY,
    BatchID BIGINT NOT NULL,
    SourceProductID VARCHAR(100),
    SourceSKU VARCHAR(100),
    SourceProductName VARCHAR(255),
    SourceCategory VARCHAR(100),
    SourceSupplier VARCHAR(150),
    SourcePrice VARCHAR(50),
    SourceStatus VARCHAR(50),
    ExtractedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Data-quality check: blank or malformed prices must be reviewed/rejected before CAST.
SELECT StagingRowID, BatchID, SourceSKU, SourcePrice
FROM Stg_RawProducts
WHERE TRIM(COALESCE(SourcePrice, '')) = ''
   OR TRIM(SourcePrice) NOT REGEXP '^[0-9]+([.][0-9]{1,2})?$';

-- 5. Duplicate SKU profiling after normalizing whitespace and case.
SELECT BatchID, UPPER(TRIM(SourceSKU)) AS NormalizedSKU, COUNT(*) AS Occurrences
FROM Stg_RawProducts
WHERE NULLIF(TRIM(SourceSKU), '') IS NOT NULL
GROUP BY BatchID, UPPER(TRIM(SourceSKU))
HAVING COUNT(*) > 1;

-- 6. Example transformation output for rows with valid-looking values.
-- Status REVIEW must be resolved by mapping rules before target loading.
SELECT
    StagingRowID,
    BatchID,
    NULLIF(TRIM(SourceSKU), '') AS CleanSKU,
    NULLIF(TRIM(SourceProductName), '') AS CleanProductName,
    CAST(TRIM(SourcePrice) AS DECIMAL(12,2)) AS CleanPrice,
    CASE LOWER(TRIM(SourceStatus))
        WHEN 'active' THEN 'Active'
        WHEN 'enabled' THEN 'Active'
        WHEN 'inactive' THEN 'Inactive'
        WHEN 'disabled' THEN 'Inactive'
        ELSE 'REVIEW'
    END AS CleanStatus
FROM Stg_RawProducts
WHERE TRIM(COALESCE(SourceSKU, '')) <> ''
  AND TRIM(COALESCE(SourceProductName, '')) <> ''
  AND TRIM(COALESCE(SourcePrice, '')) REGEXP '^[0-9]+([.][0-9]{1,2})?$';

-- 7. Reconciliation checks to perform for each batch:
-- ExtractedRows = AcceptedRows + RejectedRows.
-- LoadedRows should match accepted inserts/updates, with documented exceptions.
-- Compare source and target order/payment totals using agreed decimal rounding rules.
-- Set BatchStatus='Succeeded' and move the watermark only after checks pass.

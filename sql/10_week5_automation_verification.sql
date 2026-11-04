-- ============================================================
-- WEEK 5 AUTOMATION: VERIFICATION AND DEMONSTRATION
-- Run after 10_week5_automation_objects.sql and after Week 1 sample data.
-- MySQL 8.0+
-- ============================================================

USE VirtualRetailDB;

-- 1. Confirm automation tables exist.
SHOW TABLES;

-- 2. Confirm triggers, procedures and events were created.
SHOW TRIGGERS FROM VirtualRetailDB;
SHOW PROCEDURE STATUS WHERE Db = 'VirtualRetailDB';
SHOW EVENTS FROM VirtualRetailDB;
SHOW VARIABLES LIKE 'event_scheduler';

-- 3. Check current product inventory.
SELECT
    p.ProductID,
    p.ProductName,
    i.QuantityOnHand,
    i.ReorderLevel,
    CASE
        WHEN i.QuantityOnHand <= i.ReorderLevel THEN 'LOW STOCK'
        ELSE 'NORMAL'
    END AS StockStatus
FROM Products p
JOIN Inventory i ON i.ProductID = p.ProductID
ORDER BY i.QuantityOnHand ASC
LIMIT 20;

-- 4. Check open low-stock alerts.
SELECT
    a.AlertID,
    a.ProductID,
    p.ProductName,
    a.CurrentQuantity,
    a.ReorderLevel,
    a.AlertStatus,
    a.CreatedAt
FROM LowStockAlerts a
JOIN Products p ON p.ProductID = a.ProductID
WHERE a.AlertStatus = 'OPEN'
ORDER BY a.CreatedAt DESC;

-- 5. Check stock movement audit trail.
SELECT
    m.MovementID,
    p.ProductName,
    m.MovementType,
    m.QuantityChange,
    m.ReferenceType,
    m.ReferenceID,
    m.Remarks,
    m.CreatedAt
FROM InventoryMovements m
JOIN Products p ON p.ProductID = m.ProductID
ORDER BY m.CreatedAt DESC
LIMIT 30;

-- 6. Manually refresh one day of sales summary.
-- Replace the date with a date that exists in your Orders table.
CALL sp_refresh_daily_sales_summary('2026-11-04');

-- 7. View daily sales summaries.
SELECT *
FROM DailySalesSummary
ORDER BY SalesDate DESC
LIMIT 30;

-- 8. Test the restock procedure.
-- First choose a ProductID that exists in Inventory.
-- Example (change 1 to a real ProductID):
-- CALL sp_restock_product(1, 5, 'Teacher demonstration restock');

-- 9. Verify archive procedure without deleting live Orders.
-- Use a larger retention period during a demo if you do not have
-- old records. It copies qualifying closed-order headers only.
CALL sp_archive_closed_orders(730);

SELECT *
FROM OrdersArchive
ORDER BY ArchivedAt DESC
LIMIT 20;

-- 10. Demonstrate the low-stock alert trigger safely.
-- Do not manually change stock to an artificial value on a live system.
-- Use a disposable demo database or a transaction and ROLLBACK:
--
-- START TRANSACTION;
-- UPDATE Inventory
--    SET QuantityOnHand = ReorderLevel
--  WHERE ProductID = (SELECT ProductID FROM Products ORDER BY ProductID LIMIT 1);
-- SELECT * FROM LowStockAlerts WHERE AlertStatus = 'OPEN';
-- ROLLBACK;
--
-- NOTE: MySQL triggers execute as part of the transaction. With InnoDB,
-- rollback reverses the inventory and trigger-written alert/movement rows.

-- 11. Optional event controls (requires appropriate privileges).
-- SET GLOBAL event_scheduler = ON;
-- ALTER EVENT ev_daily_sales_summary ENABLE;
-- ALTER EVENT ev_weekly_archive_closed_orders ENABLE;
--
-- If you do not have DBA permission, ask the database administrator
-- to enable the Event Scheduler. Manual CALL statements above still
-- demonstrate the stored procedures without scheduled execution.

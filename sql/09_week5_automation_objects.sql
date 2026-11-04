-- ============================================================
-- VIRTUAL RETAIL MANAGEMENT SYSTEM
-- WEEK 5: AUTOMATION AND INTEGRATION OF SQL PROCESSES
-- Target: MySQL 8.0+
--
-- IMPORTANT:
-- 1. Run Week 1 table scripts first.
-- 2. This script creates supporting automation tables, procedures,
--    triggers and scheduled events.
-- 3. Run in MySQL Workbench using the full script (DELIMITER commands).
-- 4. The Event Scheduler may require DBA permission to enable.
-- ============================================================

USE VirtualRetailDB;

-- ------------------------------------------------------------
-- A. SUPPORTING TABLES
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS InventoryMovements (
    MovementID BIGINT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT NOT NULL,
    MovementType VARCHAR(40) NOT NULL,
    QuantityChange INT NOT NULL,
    ReferenceType VARCHAR(40) NULL,
    ReferenceID BIGINT NULL,
    Remarks VARCHAR(255) NULL,
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_InventoryMovements_Products
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX IX_InventoryMovements_Product_Created
        (ProductID, CreatedAt)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS LowStockAlerts (
    AlertID BIGINT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT NOT NULL,
    CurrentQuantity INT NOT NULL,
    ReorderLevel INT NOT NULL,
    AlertStatus VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ResolvedAt DATETIME NULL,
    CONSTRAINT FK_LowStockAlerts_Products
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    INDEX IX_LowStockAlerts_Status_Created (AlertStatus, CreatedAt),
    INDEX IX_LowStockAlerts_Product_Status (ProductID, AlertStatus)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS DailySalesSummary (
    SalesDate DATE PRIMARY KEY,
    OrdersCount INT NOT NULL DEFAULT 0,
    ItemsSold BIGINT NOT NULL DEFAULT 0,
    GrossSales DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    RefreshedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Header-level archive copy. Original operational Orders are NOT deleted.
CREATE TABLE IF NOT EXISTS OrdersArchive (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    OrderStatus VARCHAR(30) NOT NULL,
    TotalAmount DECIMAL(12,2) NOT NULL,
    ArchivedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX IX_OrdersArchive_OrderDate (OrderDate)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- B. REMOVE PREVIOUS OBJECT DEFINITIONS FOR SAFE REDEPLOYMENT
-- ------------------------------------------------------------

DROP EVENT IF EXISTS ev_daily_sales_summary;
DROP EVENT IF EXISTS ev_weekly_archive_closed_orders;

DROP PROCEDURE IF EXISTS sp_restock_product;
DROP PROCEDURE IF EXISTS sp_refresh_daily_sales_summary;
DROP PROCEDURE IF EXISTS sp_archive_closed_orders;

DROP TRIGGER IF EXISTS trg_inventory_after_insert_alert;
DROP TRIGGER IF EXISTS trg_inventory_after_update_alert;
DROP TRIGGER IF EXISTS trg_orderitems_before_insert_validate;
DROP TRIGGER IF EXISTS trg_orderitems_before_update_validate;
DROP TRIGGER IF EXISTS trg_orderitems_after_insert_deduct;
DROP TRIGGER IF EXISTS trg_orderitems_after_update_adjust;
DROP TRIGGER IF EXISTS trg_orderitems_after_delete_restore;

-- ------------------------------------------------------------
-- C. TRIGGERS: INVENTORY ALERT AUTOMATION
-- ------------------------------------------------------------

DELIMITER $$

CREATE TRIGGER trg_inventory_after_insert_alert
AFTER INSERT ON Inventory
FOR EACH ROW
BEGIN
    DECLARE v_open_count INT DEFAULT 0;

    IF NEW.QuantityOnHand <= NEW.ReorderLevel THEN
        SELECT COUNT(*)
          INTO v_open_count
          FROM LowStockAlerts
         WHERE ProductID = NEW.ProductID
           AND AlertStatus = 'OPEN';

        IF v_open_count = 0 THEN
            INSERT INTO LowStockAlerts
                (ProductID, CurrentQuantity, ReorderLevel, AlertStatus)
            VALUES
                (NEW.ProductID, NEW.QuantityOnHand, NEW.ReorderLevel, 'OPEN');
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_inventory_after_update_alert
AFTER UPDATE ON Inventory
FOR EACH ROW
BEGIN
    DECLARE v_open_count INT DEFAULT 0;

    IF NEW.QuantityOnHand <= NEW.ReorderLevel THEN
        SELECT COUNT(*)
          INTO v_open_count
          FROM LowStockAlerts
         WHERE ProductID = NEW.ProductID
           AND AlertStatus = 'OPEN';

        IF v_open_count = 0 THEN
            INSERT INTO LowStockAlerts
                (ProductID, CurrentQuantity, ReorderLevel, AlertStatus)
            VALUES
                (NEW.ProductID, NEW.QuantityOnHand, NEW.ReorderLevel, 'OPEN');
        ELSE
            UPDATE LowStockAlerts
               SET CurrentQuantity = NEW.QuantityOnHand,
                   ReorderLevel = NEW.ReorderLevel
             WHERE ProductID = NEW.ProductID
               AND AlertStatus = 'OPEN';
        END IF;
    ELSE
        UPDATE LowStockAlerts
           SET AlertStatus = 'RESOLVED',
               ResolvedAt = CURRENT_TIMESTAMP
         WHERE ProductID = NEW.ProductID
           AND AlertStatus = 'OPEN';
    END IF;
END$$

-- ------------------------------------------------------------
-- D. TRIGGERS: ORDER ITEM VALIDATION AND STOCK AUTOMATION
-- ------------------------------------------------------------

CREATE TRIGGER trg_orderitems_before_insert_validate
BEFORE INSERT ON OrderItems
FOR EACH ROW
BEGIN
    IF NEW.Quantity IS NULL OR NEW.Quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order item quantity must be greater than zero';
    END IF;

    IF NEW.UnitPrice IS NULL OR NEW.UnitPrice < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order item unit price cannot be negative';
    END IF;

    SET NEW.LineTotal = ROUND(NEW.Quantity * NEW.UnitPrice, 2);
END$$

CREATE TRIGGER trg_orderitems_before_update_validate
BEFORE UPDATE ON OrderItems
FOR EACH ROW
BEGIN
    IF NEW.Quantity IS NULL OR NEW.Quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order item quantity must be greater than zero';
    END IF;

    IF NEW.UnitPrice IS NULL OR NEW.UnitPrice < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order item unit price cannot be negative';
    END IF;

    SET NEW.LineTotal = ROUND(NEW.Quantity * NEW.UnitPrice, 2);
END$$

CREATE TRIGGER trg_orderitems_after_insert_deduct
AFTER INSERT ON OrderItems
FOR EACH ROW
BEGIN
    UPDATE Inventory
       SET QuantityOnHand = QuantityOnHand - NEW.Quantity
     WHERE ProductID = NEW.ProductID
       AND QuantityOnHand >= NEW.Quantity;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock or inventory record missing';
    END IF;

    INSERT INTO InventoryMovements
        (ProductID, MovementType, QuantityChange, ReferenceType, ReferenceID, Remarks)
    VALUES
        (NEW.ProductID, 'SALE', -NEW.Quantity, 'ORDER_ITEM',
         NEW.OrderItemID, 'Stock deducted after order item insertion');
END$$

CREATE TRIGGER trg_orderitems_after_update_adjust
AFTER UPDATE ON OrderItems
FOR EACH ROW
BEGIN
    DECLARE v_difference INT DEFAULT 0;

    IF NEW.ProductID = OLD.ProductID THEN
        IF NEW.Quantity > OLD.Quantity THEN
            SET v_difference = NEW.Quantity - OLD.Quantity;

            UPDATE Inventory
               SET QuantityOnHand = QuantityOnHand - v_difference
             WHERE ProductID = NEW.ProductID
               AND QuantityOnHand >= v_difference;

            IF ROW_COUNT() = 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Insufficient stock for increased order quantity';
            END IF;

            INSERT INTO InventoryMovements
                (ProductID, MovementType, QuantityChange, ReferenceType, ReferenceID, Remarks)
            VALUES
                (NEW.ProductID, 'SALE_ADJUSTMENT', -v_difference,
                 'ORDER_ITEM', NEW.OrderItemID, 'Additional stock deducted after quantity increase');

        ELSEIF NEW.Quantity < OLD.Quantity THEN
            SET v_difference = OLD.Quantity - NEW.Quantity;

            UPDATE Inventory
               SET QuantityOnHand = QuantityOnHand + v_difference
             WHERE ProductID = OLD.ProductID;

            IF ROW_COUNT() = 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Inventory record missing while restoring stock';
            END IF;

            INSERT INTO InventoryMovements
                (ProductID, MovementType, QuantityChange, ReferenceType, ReferenceID, Remarks)
            VALUES
                (OLD.ProductID, 'SALE_ADJUSTMENT_REVERSAL', v_difference,
                 'ORDER_ITEM', OLD.OrderItemID, 'Excess reserved quantity returned to inventory');
        END IF;

    ELSE
        -- Product changed on an existing order line:
        -- restore old product quantity, then deduct new product quantity.
        UPDATE Inventory
           SET QuantityOnHand = QuantityOnHand + OLD.Quantity
         WHERE ProductID = OLD.ProductID;

        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Old product inventory record missing';
        END IF;

        UPDATE Inventory
           SET QuantityOnHand = QuantityOnHand - NEW.Quantity
         WHERE ProductID = NEW.ProductID
           AND QuantityOnHand >= NEW.Quantity;

        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient stock for replacement product';
        END IF;

        INSERT INTO InventoryMovements
            (ProductID, MovementType, QuantityChange, ReferenceType, ReferenceID, Remarks)
        VALUES
            (OLD.ProductID, 'PRODUCT_CHANGE_RETURN', OLD.Quantity,
             'ORDER_ITEM', OLD.OrderItemID, 'Previous product quantity restored'),
            (NEW.ProductID, 'PRODUCT_CHANGE_SALE', -NEW.Quantity,
             'ORDER_ITEM', NEW.OrderItemID, 'Replacement product quantity deducted');
    END IF;
END$$

CREATE TRIGGER trg_orderitems_after_delete_restore
AFTER DELETE ON OrderItems
FOR EACH ROW
BEGIN
    UPDATE Inventory
       SET QuantityOnHand = QuantityOnHand + OLD.Quantity
     WHERE ProductID = OLD.ProductID;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Inventory record missing while restoring deleted order item';
    END IF;

    INSERT INTO InventoryMovements
        (ProductID, MovementType, QuantityChange, ReferenceType, ReferenceID, Remarks)
    VALUES
        (OLD.ProductID, 'ORDER_ITEM_DELETE_RETURN', OLD.Quantity,
         'ORDER_ITEM', OLD.OrderItemID, 'Stock restored after order item deletion');
END$$

-- ------------------------------------------------------------
-- E. STORED PROCEDURES
-- ------------------------------------------------------------

CREATE PROCEDURE sp_restock_product(
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_remarks VARCHAR(255)
)
BEGIN
    DECLARE v_inventory_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Restock quantity must be greater than zero';
    END IF;

    SELECT COUNT(*)
      INTO v_inventory_count
      FROM Inventory
     WHERE ProductID = p_product_id;

    IF v_inventory_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product inventory record does not exist';
    END IF;

    UPDATE Inventory
       SET QuantityOnHand = QuantityOnHand + p_quantity,
           UpdatedAt = CURRENT_TIMESTAMP
     WHERE ProductID = p_product_id;

    INSERT INTO InventoryMovements
        (ProductID, MovementType, QuantityChange, ReferenceType, ReferenceID, Remarks)
    VALUES
        (p_product_id, 'RESTOCK', p_quantity, 'MANUAL_RESTOCK',
         NULL, COALESCE(p_remarks, 'Stock replenishment'));

    COMMIT;

    SELECT ProductID, QuantityOnHand, ReorderLevel
      FROM Inventory
     WHERE ProductID = p_product_id;
END$$

CREATE PROCEDURE sp_refresh_daily_sales_summary(
    IN p_sales_date DATE
)
BEGIN
    IF p_sales_date IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sales date cannot be NULL';
    END IF;

    INSERT INTO DailySalesSummary
        (SalesDate, OrdersCount, ItemsSold, GrossSales)
    VALUES
    (
        p_sales_date,
        (
            SELECT COUNT(*)
              FROM Orders
             WHERE OrderDate >= p_sales_date
               AND OrderDate < p_sales_date + INTERVAL 1 DAY
               AND Status IN ('Confirmed', 'Shipped', 'Delivered')
        ),
        (
            SELECT COALESCE(SUM(oi.Quantity), 0)
              FROM OrderItems oi
              JOIN Orders o ON o.OrderID = oi.OrderID
             WHERE o.OrderDate >= p_sales_date
               AND o.OrderDate < p_sales_date + INTERVAL 1 DAY
               AND o.Status IN ('Confirmed', 'Shipped', 'Delivered')
        ),
        (
            SELECT COALESCE(SUM(TotalAmount), 0.00)
              FROM Orders
             WHERE OrderDate >= p_sales_date
               AND OrderDate < p_sales_date + INTERVAL 1 DAY
               AND Status IN ('Confirmed', 'Shipped', 'Delivered')
        )
    )
    ON DUPLICATE KEY UPDATE
        OrdersCount = VALUES(OrdersCount),
        ItemsSold = VALUES(ItemsSold),
        GrossSales = VALUES(GrossSales),
        RefreshedAt = CURRENT_TIMESTAMP;

    SELECT *
      FROM DailySalesSummary
     WHERE SalesDate = p_sales_date;
END$$

CREATE PROCEDURE sp_archive_closed_orders(
    IN p_retention_days INT
)
BEGIN
    IF p_retention_days IS NULL OR p_retention_days < 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Retention days must be at least one';
    END IF;

    INSERT INTO OrdersArchive
        (OrderID, CustomerID, OrderDate, OrderStatus, TotalAmount)
    SELECT
        OrderID, CustomerID, OrderDate, Status, TotalAmount
      FROM Orders
     WHERE OrderDate < CURRENT_TIMESTAMP - INTERVAL p_retention_days DAY
       AND Status IN ('Delivered', 'Cancelled')
    ON DUPLICATE KEY UPDATE
        CustomerID = VALUES(CustomerID),
        OrderDate = VALUES(OrderDate),
        OrderStatus = VALUES(OrderStatus),
        TotalAmount = VALUES(TotalAmount);

    SELECT ROW_COUNT() AS InsertedOrUpdatedArchiveRows;
END$$

-- ------------------------------------------------------------
-- F. SCHEDULED EVENTS
-- ------------------------------------------------------------

CREATE EVENT ev_daily_sales_summary
    ON SCHEDULE EVERY 1 DAY
    STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
    COMMENT 'Refresh the previous calendar day sales summary'
    DO
        CALL sp_refresh_daily_sales_summary(CURRENT_DATE - INTERVAL 1 DAY)$$

CREATE EVENT ev_weekly_archive_closed_orders
    ON SCHEDULE EVERY 1 WEEK
    STARTS CURRENT_TIMESTAMP + INTERVAL 7 DAY
    COMMENT 'Copy old delivered/cancelled order headers to archive table'
    DO
        CALL sp_archive_closed_orders(730)$$

DELIMITER ;

-- ------------------------------------------------------------
-- G. DEPLOYMENT CHECKS
-- ------------------------------------------------------------

SHOW TRIGGERS FROM VirtualRetailDB;
SHOW PROCEDURE STATUS WHERE Db = 'VirtualRetailDB';
SHOW EVENTS FROM VirtualRetailDB;

-- Check whether the Event Scheduler is enabled.
SHOW VARIABLES LIKE 'event_scheduler';

-- If it is OFF and you have DBA permission, an administrator can run:
-- SET GLOBAL event_scheduler = ON;
--
-- The event scheduler setting may need to be enabled in the MySQL
-- server configuration to persist after a server restart.

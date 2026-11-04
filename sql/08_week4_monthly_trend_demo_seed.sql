-- WEEK 4: OPTIONAL MULTI-MONTH DEMONSTRATION DATA
-- MySQL 8.x | Run once AFTER 01_create_tables.sql, 02_constraints_indexes.sql,
-- and 06_demo_sample_data.sql. Do not run more than once.
-- Adds 12 example orders from July to December 2026.
USE VirtualRetailDB;

INSERT INTO Orders (OrderID, CustomerID, ShippingAddressID, OrderDate, Status, TotalAmount) VALUES
(5001,1,1,'2026-07-05 10:00:00','Delivered',0.00),
(5002,2,2,'2026-07-21 14:00:00','Shipped',0.00),
(5003,3,3,'2026-08-08 11:30:00','Delivered',0.00),
(5004,4,4,'2026-08-24 16:15:00','Confirmed',0.00),
(5005,5,5,'2026-09-06 09:45:00','Delivered',0.00),
(5006,6,6,'2026-09-19 13:20:00','Shipped',0.00),
(5007,7,7,'2026-10-04 10:10:00','Delivered',0.00),
(5008,8,8,'2026-10-26 17:05:00','Confirmed',0.00),
(5009,9,9,'2026-11-09 12:00:00','Delivered',0.00),
(5010,10,10,'2026-11-22 15:40:00','Shipped',0.00),
(5011,11,11,'2026-12-03 10:30:00','Delivered',0.00),
(5012,12,12,'2026-12-18 18:10:00','Cancelled',0.00);

INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice, LineTotal)
SELECT v.OrderID, p.ProductID, v.Quantity, p.Price, p.Price * v.Quantity
FROM (
    SELECT 5001 AS OrderID, 1 AS ProductID, 2 AS Quantity UNION ALL
    SELECT 5001, 2, 1 UNION ALL SELECT 5002, 3, 1 UNION ALL SELECT 5002, 4, 2 UNION ALL
    SELECT 5003, 5, 2 UNION ALL SELECT 5003, 6, 1 UNION ALL SELECT 5004, 7, 1 UNION ALL
    SELECT 5004, 8, 3 UNION ALL SELECT 5005, 9, 2 UNION ALL SELECT 5005,10, 1 UNION ALL
    SELECT 5006,11, 1 UNION ALL SELECT 5006,12, 2 UNION ALL SELECT 5007,13, 2 UNION ALL
    SELECT 5007,14, 1 UNION ALL SELECT 5008,15, 1 UNION ALL SELECT 5008,16, 2 UNION ALL
    SELECT 5009,17, 1 UNION ALL SELECT 5009,18, 2 UNION ALL SELECT 5010,19, 2 UNION ALL
    SELECT 5010,20, 1 UNION ALL SELECT 5011,21, 1 UNION ALL SELECT 5011,22, 2 UNION ALL
    SELECT 5012,23, 1 UNION ALL SELECT 5012,24, 1
) AS v JOIN Products p ON p.ProductID = v.ProductID;

UPDATE Orders o
JOIN (SELECT OrderID, SUM(LineTotal) AS CalculatedTotal FROM OrderItems
      WHERE OrderID BETWEEN 5001 AND 5012 GROUP BY OrderID) x ON x.OrderID = o.OrderID
SET o.TotalAmount = x.CalculatedTotal;

INSERT INTO Payments (OrderID, PaymentMethod, Amount, PaymentDate, Status, TransactionRef)
SELECT o.OrderID,
       CASE MOD(o.OrderID,3) WHEN 0 THEN 'UPI' WHEN 1 THEN 'Card' ELSE 'NetBanking' END,
       o.TotalAmount, o.OrderDate,
       CASE WHEN o.Status = 'Cancelled' THEN 'Failed' ELSE 'Completed' END,
       CONCAT('TXN-W4-',o.OrderID)
FROM Orders o WHERE o.OrderID BETWEEN 5001 AND 5012;

-- Verify the newly added reporting rows.
SELECT DATE_FORMAT(OrderDate,'%Y-%m') AS SalesMonth, COUNT(*) AS OrdersAdded,
       SUM(CASE WHEN Status IN ('Confirmed','Shipped','Delivered') THEN TotalAmount ELSE 0 END) AS EligibleSales
FROM Orders WHERE OrderID BETWEEN 5001 AND 5012
GROUP BY DATE_FORMAT(OrderDate,'%Y-%m') ORDER BY SalesMonth;

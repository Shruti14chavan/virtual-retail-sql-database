-- WEEK 3: SQL QUERY OPTIMIZATION AND PERFORMANCE TUNING
-- Project: Virtual Retail Management System | MySQL 8.x
-- Run only in a development/test database after Week 1 tables exist.
-- Do not run CREATE INDEX statements repeatedly; index names must be unique.

USE VirtualRetailDB;

/* ------------------------------------------------------------
   A. BASELINE QUERIES (run and capture the plan/time BEFORE
      adding the Week 3 indexes or rewriting the query).
   ------------------------------------------------------------ */

-- Q1 BASELINE: monthly sales. DATE_FORMAT on the filtered column
-- can prevent an efficient range access on Orders.OrderDate.
SELECT DATE_FORMAT(o.OrderDate, '%Y-%m') AS SalesMonth,
       SUM(oi.LineTotal) AS TotalSales
FROM Orders AS o
JOIN OrderItems AS oi ON oi.OrderID = o.OrderID
WHERE DATE_FORMAT(o.OrderDate, '%Y-%m') = '2026-10'
  AND o.Status <> 'Cancelled'
GROUP BY DATE_FORMAT(o.OrderDate, '%Y-%m');

-- Q2 BASELINE: customer order history. Applying LOWER() to Email
-- can prevent use of a normal index on Customers.Email.
SELECT c.CustomerID, c.CustomerName, o.OrderID, o.OrderDate,
       o.Status, o.TotalAmount
FROM Customers AS c
JOIN Orders AS o ON o.CustomerID = c.CustomerID
WHERE LOWER(c.Email) = LOWER('customer@example.com')
ORDER BY o.OrderDate DESC;

-- Q3 BASELINE: order detail lookup.
SELECT oi.OrderItemID, p.ProductName, oi.Quantity,
       oi.UnitPrice, oi.LineTotal
FROM OrderItems AS oi
JOIN Products AS p ON p.ProductID = oi.ProductID
WHERE oi.OrderID = 1001;

-- Q4 BASELINE: stock lookup. ProductID is the join key.
SELECT p.ProductID, p.ProductName, i.QuantityOnHand, i.ReorderLevel
FROM Inventory AS i
JOIN Products AS p ON p.ProductID = i.ProductID
WHERE i.QuantityOnHand <= i.ReorderLevel;

/* For each baseline query, run EXPLAIN and (MySQL 8.0.18+) EXPLAIN ANALYZE.
   EXPLAIN ANALYZE EXECUTES the SELECT. Use a test database and safe SELECTs. */

-- Example:
-- EXPLAIN FORMAT=TREE <paste one SELECT here>;
-- EXPLAIN ANALYZE <paste one SELECT here>;

/* ------------------------------------------------------------
   B. OPTIONAL WEEK 3 INDEXES
   First inspect existing indexes with:
   SHOW INDEX FROM Orders;
   SHOW INDEX FROM OrderItems;
   SHOW INDEX FROM Products;
   SHOW INDEX FROM Inventory;
   Do not add an index if an equivalent or better index already exists.
   ------------------------------------------------------------ */

-- Supports date-windowed order reporting and filters by status.
CREATE INDEX IX3_Orders_Date_Status
    ON Orders (OrderDate, Status);

-- Supports order-item retrieval by order and product join lookup.
CREATE INDEX IX3_OrderItems_Order_Product
    ON OrderItems (OrderID, ProductID);

-- Supports category filtering and active-product listings.
CREATE INDEX IX3_Products_Category_Status
    ON Products (CategoryID, Status);

/* Note: Week 1 already planned indexes on Customers.Email (UNIQUE),
   Orders.CustomerID / OrderDate, OrderItems.OrderID / ProductID,
   Products.CategoryID / SupplierID, and Inventory.QuantityOnHand.
   Avoid duplicating those indexes. The composite indexes above are
   additional candidates and should be retained only if measurements
   show a benefit for the workload. */

/* ------------------------------------------------------------
   C. OPTIMIZED QUERY VERSIONS
   ------------------------------------------------------------ */

-- Q1 OPTIMIZED: use a half-open date range (sargable predicate).
-- It includes all times on 1-Oct through 31-Oct 2026.
SELECT DATE_FORMAT(o.OrderDate, '%Y-%m') AS SalesMonth,
       SUM(oi.LineTotal) AS TotalSales
FROM Orders AS o
JOIN OrderItems AS oi ON oi.OrderID = o.OrderID
WHERE o.OrderDate >= '2026-10-01'
  AND o.OrderDate <  '2026-11-01'
  AND o.Status <> 'Cancelled'
GROUP BY DATE_FORMAT(o.OrderDate, '%Y-%m');

-- Q2 OPTIMIZED: compare using the stored normalized email value.
-- This assumes email values were normalized (for example, lowercase)
-- during data entry/ETL. Do not remove LOWER() unless this rule is enforced.
SELECT c.CustomerID, c.CustomerName, o.OrderID, o.OrderDate,
       o.Status, o.TotalAmount
FROM Customers AS c
JOIN Orders AS o ON o.CustomerID = c.CustomerID
WHERE c.Email = 'customer@example.com'
ORDER BY o.OrderDate DESC;

-- Q3 OPTIMIZED: query shape is unchanged; the composite index can
-- support the OrderID filter and ProductID join. Verify with EXPLAIN.
SELECT oi.OrderItemID, p.ProductName, oi.Quantity,
       oi.UnitPrice, oi.LineTotal
FROM OrderItems AS oi
JOIN Products AS p ON p.ProductID = oi.ProductID
WHERE oi.OrderID = 1001;

-- Q4 OPTIMIZED OPTION: the generated flag stores the result of the
-- per-row comparison and can be indexed. Add the column/index ONCE.
-- Test selectivity: if almost every row is low-stock or not-low-stock,
-- the optimizer may still prefer a scan.
ALTER TABLE Inventory
    ADD COLUMN IsLowStock TINYINT
    GENERATED ALWAYS AS (QuantityOnHand <= ReorderLevel) STORED;
CREATE INDEX IX3_Inventory_IsLowStock ON Inventory (IsLowStock, ProductID);

SELECT p.ProductID, p.ProductName, i.QuantityOnHand, i.ReorderLevel
FROM Inventory AS i
JOIN Products AS p ON p.ProductID = i.ProductID
WHERE i.IsLowStock = 1;

/* ------------------------------------------------------------
   D. BENCHMARK AND DIAGNOSTIC COMMANDS
   ------------------------------------------------------------ */

-- Inspect index definitions:
SHOW INDEX FROM Orders;
SHOW INDEX FROM OrderItems;
SHOW INDEX FROM Products;
SHOW INDEX FROM Inventory;

-- Refresh optimizer statistics after a significant data/index change:
ANALYZE TABLE Orders, OrderItems, Products, Inventory, Customers;

-- Run before and after for each query:
-- EXPLAIN FORMAT=TREE SELECT ...;
-- EXPLAIN ANALYZE SELECT ...;

-- Optional: record each timing manually in the report's benchmark table.
-- Use the same test data, parameter values, server, and concurrency.
-- Run each query several times; compare median elapsed time, not one run.

/* ------------------------------------------------------------
   E. PARTITIONING DECISION
   ------------------------------------------------------------ */
-- Do not partition Orders automatically for this assignment.
-- Consider date-based partitioning only for very large date-driven tables
-- after measuring retention/maintenance benefits and checking the exact
-- MySQL version's partitioning and foreign-key restrictions. Partitioning
-- adds operational complexity and is not a substitute for good indexes.

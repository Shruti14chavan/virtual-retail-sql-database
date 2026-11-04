-- WEEK 3 FEEDBACK ADDENDUM: BENCHMARK EXAMPLES
-- MySQL 8.x. Capture EXPLAIN ANALYZE output and timings in Workbench.
USE VirtualRetailDB;

-- A) Baseline: function on date column
EXPLAIN ANALYZE
SELECT OrderID, TotalAmount
FROM Orders
WHERE DATE_FORMAT(OrderDate,'%Y-%m') = '2026-10';

-- B) Optimized: half-open date range
EXPLAIN ANALYZE
SELECT OrderID, TotalAmount
FROM Orders
WHERE OrderDate >= '2026-10-01'
  AND OrderDate <  '2026-11-01';

-- C) Before/after customer history index
-- Capture this plan before creating the index.
EXPLAIN ANALYZE
SELECT OrderID, OrderDate, Status, TotalAmount
FROM Orders
WHERE CustomerID = 25
  AND OrderDate >= '2026-10-01'
  AND OrderDate <  '2026-11-01'
ORDER BY OrderDate DESC;

-- Create once only; skip if IX_Orders_Customer_OrderDate already exists.
CREATE INDEX IX_Orders_Customer_OrderDate
ON Orders(CustomerID, OrderDate);

-- Capture the plan again after index creation.
EXPLAIN ANALYZE
SELECT OrderID, OrderDate, Status, TotalAmount
FROM Orders
WHERE CustomerID = 25
  AND OrderDate >= '2026-10-01'
  AND OrderDate <  '2026-11-01'
ORDER BY OrderDate DESC;

SHOW INDEX FROM Orders;

-- Benchmark protocol:
-- 1. Warm up once, then time 5 runs of each version.
-- 2. Record five observed times and median in the Week 3 addendum.
-- 3. Compare actual rows/loops/access path from EXPLAIN ANALYZE.
-- 4. Confirm same result set before claiming improvement.
-- Do not invent elapsed times; optimizer choices depend on data and environment.

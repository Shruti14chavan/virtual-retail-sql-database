-- WEEK 4: DYNAMIC REPORTING AND DATA VISUALIZATION USING SQL
-- Project: Virtual Retail Management System | MySQL 8.x
-- Assumes Week 1 tables exist in VirtualRetailDB and sample/demo data has been loaded.
-- Run 09_week4_monthly_trend_demo_seed.sql once after the Week 1 demo seed to add Jul-Dec examples.
-- Change the parameters for another reporting period.

USE VirtualRetailDB;
SET @report_start = '2026-07-01';
SET @report_end   = '2027-01-01'; -- exclusive end date; Jul-Dec 2026
SET @as_of_date   = DATE_SUB(@report_end, INTERVAL 1 DAY);

-- REPORT 1: Executive KPI summary. Do not join Payments directly to Orders here;
-- separate subqueries avoid multiplying order totals when multiple payments exist.
SELECT
    COUNT(*) AS EligibleOrders,
    COUNT(DISTINCT CustomerID) AS PurchasingCustomers,
    ROUND(SUM(TotalAmount), 2) AS NetOrderValue,
    ROUND(AVG(TotalAmount), 2) AS AverageOrderValue,
    (SELECT ROUND(COALESCE(SUM(Amount),0),2)
       FROM Payments
      WHERE Status = 'Completed'
        AND PaymentDate >= @report_start
        AND PaymentDate <  @report_end) AS CompletedPaymentValue
FROM Orders
WHERE OrderDate >= @report_start
  AND OrderDate <  @report_end
  AND Status IN ('Confirmed','Shipped','Delivered');

-- REPORT 2: Monthly net sales trend and month-over-month change.
WITH monthly_sales AS (
    SELECT DATE_FORMAT(OrderDate,'%Y-%m') AS SalesMonth,
           SUM(TotalAmount) AS NetSales,
           COUNT(*) AS OrderCount
    FROM Orders
    WHERE OrderDate >= @report_start AND OrderDate < @report_end
      AND Status IN ('Confirmed','Shipped','Delivered')
    GROUP BY DATE_FORMAT(OrderDate,'%Y-%m')
), trend AS (
    SELECT SalesMonth, NetSales, OrderCount,
           LAG(NetSales) OVER (ORDER BY SalesMonth) AS PreviousMonthSales
    FROM monthly_sales
)
SELECT SalesMonth, ROUND(NetSales,2) AS NetSales, OrderCount,
       ROUND(100.0 * (NetSales - PreviousMonthSales) / NULLIF(PreviousMonthSales,0),2) AS MoMChangePercent
FROM trend
ORDER BY SalesMonth;

-- REPORT 3: Category revenue and contribution percentage.
WITH category_sales AS (
    SELECT c.CategoryID, c.CategoryName, SUM(oi.LineTotal) AS Revenue
    FROM Categories c
    JOIN Products p ON p.CategoryID = c.CategoryID
    JOIN OrderItems oi ON oi.ProductID = p.ProductID
    JOIN Orders o ON o.OrderID = oi.OrderID
    WHERE o.OrderDate >= @report_start AND o.OrderDate < @report_end
      AND o.Status IN ('Confirmed','Shipped','Delivered')
    GROUP BY c.CategoryID, c.CategoryName
)
SELECT CategoryName, ROUND(Revenue,2) AS Revenue,
       ROUND(100.0 * Revenue / NULLIF(SUM(Revenue) OVER (),0),2) AS RevenueSharePercent
FROM category_sales
ORDER BY Revenue DESC;

-- REPORT 4: Best-selling products by units and revenue (Top 10).
SELECT p.ProductID, p.ProductName, p.SKU,
       SUM(oi.Quantity) AS UnitsSold,
       ROUND(SUM(oi.LineTotal),2) AS ProductRevenue
FROM Products p
JOIN OrderItems oi ON oi.ProductID = p.ProductID
JOIN Orders o ON o.OrderID = oi.OrderID
WHERE o.OrderDate >= @report_start AND o.OrderDate < @report_end
  AND o.Status IN ('Confirmed','Shipped','Delivered')
GROUP BY p.ProductID, p.ProductName, p.SKU
ORDER BY UnitsSold DESC, ProductRevenue DESC
LIMIT 10;

-- REPORT 5: Inventory health / reorder watchlist.
SELECT p.ProductID, p.ProductName, p.SKU,
       i.QuantityOnHand, i.ReorderLevel,
       CASE WHEN i.QuantityOnHand = 0 THEN 'OUT OF STOCK'
            WHEN i.QuantityOnHand <= i.ReorderLevel THEN 'REORDER'
            WHEN i.QuantityOnHand <= i.ReorderLevel * 1.5 THEN 'LOW'
            ELSE 'HEALTHY' END AS StockStatus
FROM Products p
JOIN Inventory i ON i.ProductID = p.ProductID
WHERE p.Status = 'Active'
ORDER BY CASE WHEN i.QuantityOnHand = 0 THEN 1
              WHEN i.QuantityOnHand <= i.ReorderLevel THEN 2
              WHEN i.QuantityOnHand <= i.ReorderLevel * 1.5 THEN 3 ELSE 4 END,
         i.QuantityOnHand ASC;

-- REPORT 6: Stock coverage estimate based on average daily units sold in the last 30 days.
-- This is a stock-coverage estimate, not accounting inventory turnover.
WITH product_velocity AS (
    SELECT oi.ProductID, SUM(oi.Quantity) / 30.0 AS AvgUnitsPerDay
    FROM OrderItems oi
    JOIN Orders o ON o.OrderID = oi.OrderID
    WHERE o.OrderDate >= DATE_SUB(@report_end, INTERVAL 30 DAY)
      AND o.OrderDate < @report_end
      AND o.Status IN ('Confirmed','Shipped','Delivered')
    GROUP BY oi.ProductID
)
SELECT p.ProductName, i.QuantityOnHand,
       ROUND(COALESCE(v.AvgUnitsPerDay,0),2) AS AvgUnitsSoldPerDay,
       CASE WHEN COALESCE(v.AvgUnitsPerDay,0) = 0 THEN NULL
            ELSE ROUND(i.QuantityOnHand / v.AvgUnitsPerDay,1) END AS EstimatedDaysOfStock
FROM Products p
JOIN Inventory i ON i.ProductID = p.ProductID
LEFT JOIN product_velocity v ON v.ProductID = p.ProductID
ORDER BY EstimatedDaysOfStock ASC;

-- REPORT 7: Customer behaviour / RFM-style segmentation.
WITH customer_metrics AS (
    SELECT c.CustomerID, c.CustomerName,
           MAX(o.OrderDate) AS LastOrderDate,
           COUNT(o.OrderID) AS OrderFrequency,
           COALESCE(SUM(o.TotalAmount),0) AS MonetaryValue
    FROM Customers c
    LEFT JOIN Orders o
      ON o.CustomerID = c.CustomerID
     AND o.OrderDate >= @report_start AND o.OrderDate < @report_end
     AND o.Status IN ('Confirmed','Shipped','Delivered')
    GROUP BY c.CustomerID, c.CustomerName
)
SELECT CustomerID, CustomerName, LastOrderDate, OrderFrequency,
       ROUND(MonetaryValue,2) AS MonetaryValue,
       CASE WHEN OrderFrequency = 0 THEN 'No purchase in period'
            WHEN OrderFrequency = 1 THEN 'One-time buyer'
            WHEN OrderFrequency >= 3 THEN 'Frequent buyer'
            ELSE 'Repeat buyer' END AS CustomerSegment
FROM customer_metrics
ORDER BY MonetaryValue DESC;

-- REPORT 8: Repeat-purchase rate for the selected period.
WITH customer_order_counts AS (
    SELECT CustomerID, COUNT(*) AS OrderCount
    FROM Orders
    WHERE OrderDate >= @report_start AND OrderDate < @report_end
      AND Status IN ('Confirmed','Shipped','Delivered')
    GROUP BY CustomerID
)
SELECT COUNT(*) AS PurchasingCustomers,
       SUM(CASE WHEN OrderCount >= 2 THEN 1 ELSE 0 END) AS RepeatCustomers,
       ROUND(100.0 * SUM(CASE WHEN OrderCount >= 2 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*),0),2) AS RepeatCustomerPercent
FROM customer_order_counts;

-- REPORT 9: Payment method mix and success rate.
SELECT PaymentMethod,
       COUNT(*) AS PaymentAttempts,
       SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END) AS SuccessfulPayments,
       ROUND(100.0 * SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*),0),2) AS SuccessRatePercent,
       ROUND(SUM(CASE WHEN Status = 'Completed' THEN Amount ELSE 0 END),2) AS CollectedAmount
FROM Payments
WHERE PaymentDate >= @report_start AND PaymentDate < @report_end
GROUP BY PaymentMethod
ORDER BY CollectedAmount DESC;

-- REPORT 10: Best sales weekdays (for staffing / campaign scheduling).
SELECT DAYNAME(OrderDate) AS WeekdayName,
       DAYOFWEEK(OrderDate) AS WeekdayNumber,
       COUNT(*) AS OrderCount,
       ROUND(SUM(TotalAmount),2) AS NetSales
FROM Orders
WHERE OrderDate >= @report_start AND OrderDate < @report_end
  AND Status IN ('Confirmed','Shipped','Delivered')
GROUP BY DAYNAME(OrderDate), DAYOFWEEK(OrderDate)
ORDER BY WeekdayNumber;

-- REPORT 11: Sales by hour (for operational staffing and campaign timing).
SELECT HOUR(OrderDate) AS OrderHour,
       COUNT(*) AS OrderCount,
       ROUND(SUM(TotalAmount),2) AS NetSales
FROM Orders
WHERE OrderDate >= @report_start AND OrderDate < @report_end
  AND Status IN ('Confirmed','Shipped','Delivered')
GROUP BY HOUR(OrderDate)
ORDER BY OrderHour;

-- REPORT 12: Top customers by spend in selected period.
SELECT c.CustomerID, c.CustomerName,
       COUNT(o.OrderID) AS OrdersPlaced,
       ROUND(SUM(o.TotalAmount),2) AS CustomerSpend
FROM Customers c
JOIN Orders o ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= @report_start AND o.OrderDate < @report_end
  AND o.Status IN ('Confirmed','Shipped','Delivered')
GROUP BY c.CustomerID, c.CustomerName
ORDER BY CustomerSpend DESC
LIMIT 10;

-- OPTIONAL EXTENSION: Historical inventory snapshots for a true unit-based inventory turnover analysis.
-- The Week 1 Inventory table stores only current stock. Historical turnover requires snapshots over time.
CREATE TABLE IF NOT EXISTS InventorySnapshots (
    SnapshotID BIGINT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT NOT NULL,
    SnapshotDate DATE NOT NULL,
    QuantityOnHand INT NOT NULL,
    UNIQUE KEY UQ_InventorySnapshot_ProductDate (ProductID, SnapshotDate),
    CONSTRAINT CK_InventorySnapshot_Qty CHECK (QuantityOnHand >= 0),
    CONSTRAINT FK_InventorySnapshot_Product FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

-- After daily snapshots have been loaded, calculate unit-based turnover over the period.
-- Unit turnover = units sold during period / average daily units in stock.
WITH sold AS (
    SELECT oi.ProductID, SUM(oi.Quantity) AS UnitsSold
    FROM OrderItems oi
    JOIN Orders o ON o.OrderID = oi.OrderID
    WHERE o.OrderDate >= @report_start AND o.OrderDate < @report_end
      AND o.Status IN ('Confirmed','Shipped','Delivered')
    GROUP BY oi.ProductID
), avg_stock AS (
    SELECT ProductID, AVG(QuantityOnHand) AS AvgDailyStock
    FROM InventorySnapshots
    WHERE SnapshotDate >= @report_start AND SnapshotDate < @report_end
    GROUP BY ProductID
)
SELECT p.ProductName, COALESCE(s.UnitsSold,0) AS UnitsSold,
       ROUND(a.AvgDailyStock,2) AS AverageDailyStock,
       ROUND(COALESCE(s.UnitsSold,0) / NULLIF(a.AvgDailyStock,0),2) AS UnitTurnoverRatio
FROM Products p
LEFT JOIN sold s ON s.ProductID = p.ProductID
LEFT JOIN avg_stock a ON a.ProductID = p.ProductID
WHERE a.AvgDailyStock IS NOT NULL
ORDER BY UnitTurnoverRatio DESC;

-- DATA VALIDATION CHECK: the sum of line totals should be compared with order headers.
SELECT o.OrderID, o.TotalAmount AS HeaderTotal,
       COALESCE(SUM(oi.LineTotal),0) AS CalculatedLineTotal,
       ROUND(o.TotalAmount - COALESCE(SUM(oi.LineTotal),0),2) AS Difference
FROM Orders o
LEFT JOIN OrderItems oi ON oi.OrderID = o.OrderID
WHERE o.OrderDate >= @report_start AND o.OrderDate < @report_end
GROUP BY o.OrderID, o.TotalAmount
HAVING ABS(o.TotalAmount - COALESCE(SUM(oi.LineTotal),0)) > 0.01;

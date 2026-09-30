-- Virtual Retail Management System
-- Week 1: Sample SQL Queries
-- Compatible with MySQL 8.x

USE VirtualRetailDB;

-- ============================================================
-- 1. Display all active products
-- ============================================================
SELECT
    ProductID,
    ProductName,
    SKU,
    Price
FROM Products
WHERE Status = 'Active'
ORDER BY ProductName;


-- ============================================================
-- 2. Display products with their category and supplier
-- ============================================================
SELECT
    p.ProductID,
    p.ProductName,
    p.SKU,
    p.Price,
    c.CategoryName,
    s.SupplierName
FROM Products p
JOIN Categories c
    ON p.CategoryID = c.CategoryID
JOIN Suppliers s
    ON p.SupplierID = s.SupplierID
ORDER BY p.ProductName;


-- ============================================================
-- 3. Find low-stock products
-- ============================================================
SELECT
    p.ProductID,
    p.ProductName,
    i.QuantityOnHand,
    i.ReorderLevel
FROM Inventory i
JOIN Products p
    ON i.ProductID = p.ProductID
WHERE i.QuantityOnHand <= i.ReorderLevel
ORDER BY i.QuantityOnHand ASC;


-- ============================================================
-- 4. Display customer order history
-- ============================================================
SELECT
    c.CustomerID,
    c.CustomerName,
    o.OrderID,
    o.OrderDate,
    o.Status,
    o.TotalAmount
FROM Customers c
JOIN Orders o
    ON c.CustomerID = o.CustomerID
ORDER BY c.CustomerID, o.OrderDate DESC;


-- ============================================================
-- 5. Show items for a particular order
-- Change 1 to the required OrderID.
-- ============================================================
SELECT
    oi.OrderItemID,
    o.OrderID,
    p.ProductName,
    oi.Quantity,
    oi.UnitPrice,
    oi.LineTotal
FROM OrderItems oi
JOIN Orders o
    ON oi.OrderID = o.OrderID
JOIN Products p
    ON oi.ProductID = p.ProductID
WHERE o.OrderID = 1;


-- ============================================================
-- 6. Calculate total quantity sold for each product
-- ============================================================
SELECT
    p.ProductID,
    p.ProductName,
    COALESCE(SUM(oi.Quantity), 0) AS TotalQuantitySold
FROM Products p
LEFT JOIN OrderItems oi
    ON p.ProductID = oi.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalQuantitySold DESC;


-- ============================================================
-- 7. Calculate sales by category
-- ============================================================
SELECT
    c.CategoryName,
    SUM(oi.LineTotal) AS CategorySales
FROM Categories c
JOIN Products p
    ON c.CategoryID = p.CategoryID
JOIN OrderItems oi
    ON p.ProductID = oi.ProductID
JOIN Orders o
    ON oi.OrderID = o.OrderID
WHERE o.Status <> 'Cancelled'
GROUP BY c.CategoryID, c.CategoryName
ORDER BY CategorySales DESC;


-- ============================================================
-- 8. Count orders for each customer
-- ============================================================
SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(o.OrderID) AS TotalOrders
FROM Customers c
LEFT JOIN Orders o
    ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.CustomerName
ORDER BY TotalOrders DESC;


-- ============================================================
-- 9. Find customers whose total confirmed/delivered spending
--    is greater than 5000
-- ============================================================
SELECT
    c.CustomerID,
    c.CustomerName,
    SUM(o.TotalAmount) AS TotalSpent
FROM Customers c
JOIN Orders o
    ON c.CustomerID = o.CustomerID
WHERE o.Status IN ('Confirmed', 'Shipped', 'Delivered')
GROUP BY c.CustomerID, c.CustomerName
HAVING SUM(o.TotalAmount) > 5000
ORDER BY TotalSpent DESC;


-- ============================================================
-- 10. Show completed payments with customer and order
-- ============================================================
SELECT
    pay.PaymentID,
    pay.OrderID,
    c.CustomerName,
    pay.PaymentMethod,
    pay.Amount,
    pay.PaymentDate,
    pay.Status,
    pay.TransactionRef
FROM Payments pay
JOIN Orders o
    ON pay.OrderID = o.OrderID
JOIN Customers c
    ON o.CustomerID = c.CustomerID
WHERE pay.Status = 'Completed'
ORDER BY pay.PaymentDate DESC;


-- ============================================================
-- 11. Monthly sales report
-- ============================================================
SELECT
    DATE_FORMAT(OrderDate, '%Y-%m') AS SalesMonth,
    SUM(TotalAmount) AS TotalSales
FROM Orders
WHERE Status <> 'Cancelled'
GROUP BY DATE_FORMAT(OrderDate, '%Y-%m')
ORDER BY SalesMonth;


-- ============================================================
-- 12. Find the top 5 selling products by quantity
-- ============================================================
SELECT
    p.ProductID,
    p.ProductName,
    SUM(oi.Quantity) AS TotalQuantitySold
FROM OrderItems oi
JOIN Products p
    ON oi.ProductID = p.ProductID
JOIN Orders o
    ON oi.OrderID = o.OrderID
WHERE o.Status <> 'Cancelled'
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalQuantitySold DESC
LIMIT 5;


-- ============================================================
-- 13. Count products in each category
-- ============================================================
SELECT
    c.CategoryID,
    c.CategoryName,
    COUNT(p.ProductID) AS ProductCount
FROM Categories c
LEFT JOIN Products p
    ON c.CategoryID = p.CategoryID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY ProductCount DESC;


-- ============================================================
-- 14. Find suppliers providing active products
-- ============================================================
SELECT DISTINCT
    s.SupplierID,
    s.SupplierName,
    s.Email,
    s.Phone
FROM Suppliers s
JOIN Products p
    ON s.SupplierID = p.SupplierID
WHERE p.Status = 'Active'
ORDER BY s.SupplierName;


-- ============================================================
-- 15. Verify an order total from its order items
-- ============================================================
SELECT
    o.OrderID,
    o.TotalAmount AS StoredOrderTotal,
    COALESCE(SUM(oi.LineTotal), 0) AS CalculatedOrderTotal
FROM Orders o
LEFT JOIN OrderItems oi
    ON o.OrderID = oi.OrderID
WHERE o.OrderID = 1
GROUP BY o.OrderID, o.TotalAmount;

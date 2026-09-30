-- Virtual Retail Management System
-- Week 1: Constraints and Indexes
-- Compatible with MySQL 8.x

USE VirtualRetailDB;

-- Unique constraints / business keys
ALTER TABLE Customers
    ADD CONSTRAINT UQ_Customers_Email UNIQUE (Email);

ALTER TABLE Categories
    ADD CONSTRAINT UQ_Categories_CategoryName UNIQUE (CategoryName);

ALTER TABLE Products
    ADD CONSTRAINT UQ_Products_SKU UNIQUE (SKU);

ALTER TABLE Inventory
    ADD CONSTRAINT UQ_Inventory_ProductID UNIQUE (ProductID);

ALTER TABLE Payments
    ADD CONSTRAINT UQ_Payments_TransactionRef UNIQUE (TransactionRef);

-- Indexes for common searches and joins
CREATE INDEX IX_Addresses_CustomerID
    ON Addresses(CustomerID);

CREATE INDEX IX_Products_CategoryID
    ON Products(CategoryID);

CREATE INDEX IX_Products_SupplierID
    ON Products(SupplierID);

CREATE INDEX IX_Orders_CustomerID
    ON Orders(CustomerID);

CREATE INDEX IX_Orders_OrderDate
    ON Orders(OrderDate);

CREATE INDEX IX_Orders_Customer_OrderDate
    ON Orders(CustomerID, OrderDate);

CREATE INDEX IX_OrderItems_OrderID
    ON OrderItems(OrderID);

CREATE INDEX IX_OrderItems_ProductID
    ON OrderItems(ProductID);

CREATE INDEX IX_Payments_OrderID
    ON Payments(OrderID);

-- Useful low-stock reporting index
CREATE INDEX IX_Inventory_QuantityOnHand
    ON Inventory(QuantityOnHand);

-- Optional status indexes for operational filtering
CREATE INDEX IX_Orders_Status
    ON Orders(Status);

CREATE INDEX IX_Products_Status
    ON Products(Status);

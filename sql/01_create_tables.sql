-- Virtual Retail Management System
-- Week 1: Create Tables
-- Compatible with MySQL 8.x

CREATE DATABASE IF NOT EXISTS VirtualRetailDB;
USE VirtualRetailDB;

-- 1. Customers
CREATE TABLE IF NOT EXISTS Customers (
    CustomerID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerName VARCHAR(150) NOT NULL,
    Email VARCHAR(150) NOT NULL,
    Phone VARCHAR(20),
    CreatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active'
);

-- 2. Addresses
CREATE TABLE IF NOT EXISTS Addresses (
    AddressID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT NOT NULL,
    AddressLine1 VARCHAR(200) NOT NULL,
    City VARCHAR(100) NOT NULL,
    State VARCHAR(100) NOT NULL,
    Pincode VARCHAR(10) NOT NULL,
    AddressType VARCHAR(20) NOT NULL DEFAULT 'Home',
    CONSTRAINT FK_Addresses_Customers
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID)
);

-- 3. Categories
CREATE TABLE IF NOT EXISTS Categories (
    CategoryID INT AUTO_INCREMENT PRIMARY KEY,
    CategoryName VARCHAR(100) NOT NULL,
    Description VARCHAR(500),
    Status VARCHAR(20) NOT NULL DEFAULT 'Active'
);

-- 4. Suppliers
CREATE TABLE IF NOT EXISTS Suppliers (
    SupplierID INT AUTO_INCREMENT PRIMARY KEY,
    SupplierName VARCHAR(150) NOT NULL,
    Email VARCHAR(150),
    Phone VARCHAR(20),
    Status VARCHAR(20) NOT NULL DEFAULT 'Active'
);

-- 5. Products
CREATE TABLE IF NOT EXISTS Products (
    ProductID INT AUTO_INCREMENT PRIMARY KEY,
    CategoryID INT NOT NULL,
    SupplierID INT NOT NULL,
    ProductName VARCHAR(200) NOT NULL,
    SKU VARCHAR(50) NOT NULL,
    Price DECIMAL(12,2) NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT CK_Products_Price CHECK (Price >= 0),
    CONSTRAINT FK_Products_Categories
        FOREIGN KEY (CategoryID)
        REFERENCES Categories(CategoryID),
    CONSTRAINT FK_Products_Suppliers
        FOREIGN KEY (SupplierID)
        REFERENCES Suppliers(SupplierID)
);

-- 6. Inventory
CREATE TABLE IF NOT EXISTS Inventory (
    InventoryID INT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT NOT NULL,
    QuantityOnHand INT NOT NULL DEFAULT 0,
    ReorderLevel INT NOT NULL DEFAULT 10,
    UpdatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT CK_Inventory_Quantity CHECK (QuantityOnHand >= 0),
    CONSTRAINT CK_Inventory_ReorderLevel CHECK (ReorderLevel >= 0),
    CONSTRAINT FK_Inventory_Products
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
);

-- 7. Orders
CREATE TABLE IF NOT EXISTS Orders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT NOT NULL,
    ShippingAddressID INT,
    OrderDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status VARCHAR(30) NOT NULL DEFAULT 'Pending',
    TotalAmount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT CK_Orders_TotalAmount CHECK (TotalAmount >= 0),
    CONSTRAINT FK_Orders_Customers
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Orders_ShippingAddress
        FOREIGN KEY (ShippingAddressID)
        REFERENCES Addresses(AddressID)
);

-- 8. OrderItems
CREATE TABLE IF NOT EXISTS OrderItems (
    OrderItemID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(12,2) NOT NULL,
    LineTotal DECIMAL(12,2) NOT NULL,
    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT CK_OrderItems_LineTotal CHECK (LineTotal >= 0),
    CONSTRAINT FK_OrderItems_Orders
        FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID),
    CONSTRAINT FK_OrderItems_Products
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
);

-- 9. Payments
CREATE TABLE IF NOT EXISTS Payments (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL,
    PaymentMethod VARCHAR(30) NOT NULL,
    Amount DECIMAL(12,2) NOT NULL,
    PaymentDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    TransactionRef VARCHAR(100),
    CONSTRAINT CK_Payments_Amount CHECK (Amount >= 0),
    CONSTRAINT FK_Payments_Orders
        FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID)
);

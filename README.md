# Virtual Retail Management System – SQL Database

## Project Overview

This project is a relational database design for a Virtual Retail Management System. The purpose of the project is to organize and manage the major operations of an online retail business using SQL.

The database manages customer information, customer addresses, products, categories, suppliers, inventory, orders, order items, and payments.

The Week 1 objective is to convert virtual retail business requirements into a clear, normalized, and scalable relational database design.

## Objectives

- Design a relational database for virtual retail operations.
- Identify entities, attributes, primary keys, and foreign keys.
- Create an Entity Relationship Diagram (ERD).
- Apply normalization principles up to Third Normal Form (3NF).
- Define useful indexes and data-integrity constraints.
- Provide a scalable database architecture.
- Prepare SQL scripts for table creation and sample queries.

## Technologies Used

- SQL
- MySQL / SQL Server
- GitHub
- ER Diagram

## Main Database Entities

1. Customers
2. Addresses
3. Categories
4. Suppliers
5. Products
6. Inventory
7. Orders
8. OrderItems
9. Payments

## Database Relationships

- One Customer can have many Addresses.
- One Customer can place many Orders.
- One Category can contain many Products.
- One Supplier can supply many Products.
- One Product has an Inventory record in the initial design.
- One Order can contain many OrderItems.
- One Product can appear in many OrderItems.
- One Order has a Payment record in the initial design.

## Key Database Features

- Primary keys for unique record identification.
- Foreign keys for maintaining relationships.
- Unique constraints for fields such as email and SKU.
- Normalization to reduce unnecessary data duplication.
- Indexing for commonly searched and joined columns.
- Transaction handling for order and inventory operations.
- Data validation for quantities, prices, and statuses.

## Project Structure

```text
virtual-retail-sql-database/
│
├── README.md
│
├── docs/
│   ├── ERD.png
│   └── Week_1_Report.docx
│
└── sql/
    ├── 01_create_tables.sql
    ├── 02_constraints_indexes.sql
    └── 03_sample_queries.sql
```

## Setup Instructions

1. Install MySQL or SQL Server.
2. Create a database named `VirtualRetailDB`.
3. Run `01_create_tables.sql` to create the main tables.
4. Run `02_constraints_indexes.sql` to add constraints and indexes.
5. Run `03_sample_queries.sql` to test example SQL queries.
6. Open `docs/ERD.png` to view the database relationships.

## Week 1 Deliverable

This repository contains the Week 1 Data Modeling and Architecture Design deliverables for the Virtual Retail SQL Developer Internship.

The deliverables include the ERD, database design documentation, relational schema, normalization approach, indexing strategy, and SQL scripts.

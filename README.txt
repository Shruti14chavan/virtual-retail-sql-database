WEEK 5 — AUTOMATION AND INTEGRATION OF SQL PROCESSES
======================================================

Deliverables:
- docs/Week_5_Automation_and_Integration_Report.docx
  Full Week 5 report, implementation design, flowchart, SQL examples,
  deployment steps and test plan.
- docs/Week5_Automation_Flowchart.png
  Standalone automation workflow diagram.
- sql/10_week5_automation_objects.sql
  Creates supporting tables, triggers, stored procedures and scheduled events.
- sql/11_week5_automation_verification.sql
  Verification and teacher demonstration queries.

Run order:
1. Run the Week 1 schema creation script and load sample data.
2. Confirm Inventory, Orders and OrderItems match the expected columns in the report.
3. Run 10_week5_automation_objects.sql.
4. Run 11_week5_automation_verification.sql.
5. Enable MySQL Event Scheduler only with appropriate administrator permission.

Requirements:
- MySQL 8.0+
- InnoDB tables
- Permissions to create tables, triggers, routines and events
- Event Scheduler ON for scheduled execution

Important design notes:
- The order-item trigger deducts inventory at order-line insert and restores stock
  when an order line is reduced, replaced or deleted. A production system should
  implement the full order/payment/cancellation lifecycle in controlled procedures.
- OrdersArchive is a copy of older closed order headers. Live Orders are not deleted.
- External email/SMS is not sent directly by SQL triggers; alerts are stored in
  LowStockAlerts for an application or notification service to process.
- Test on a development database before using real business data.

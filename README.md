# 🚀 Consumer Goods Sales Analysis — SQL + Excel Analytics

SQL + Excel–based analytics on 1L+ transactions uncovering drivers of flat revenue, high cancellations, churn risk, returns, shipment delays, and payment leakage using T-SQL and ad-hoc Excel analysis.

**Domain:** Consumer Goods / Retail | **Database:** SQL Server (T-SQL)

---

## 📌 Business Context

A consumer goods distributor operating across 4 regions had no consolidated reporting layer.
Data was siloed across multiple systems and management lacked visibility into revenue trends, cancellations, churn, and payment realisation.

This project builds a structured SQL analytics layer replacing ad hoc Excel reporting with repeatable, production-ready queries.

---

## 📦 Dataset Overview

| Table         | Rows     | Description                         |
| ------------- | -------- | ----------------------------------- |
| Fact_Sales    | 1,00,140 | Orders, revenue, quantity, discount |
| Fact_Shipment | 59,950   | Ship & delivery data                |
| Fact_Returns  | 9,037    | Return reasons & refunds            |
| Fact_Payments | 60,079   | Payment status tracking             |
| Dim_Order     | 40,000   | Channel & priority                  |
| Dim_Customer  | 5,000    | Customer master                     |
| Dim_Product   | 500      | Category hierarchy                  |
| Dim_Region    | 4        | Regions                             |
| Dim_Supplier  | 50       | Supplier details                    |
| Dim_Date      | 1,461    | Date dimension                      |

---

## 🎯 Key Business Metrics

| Metric               | Value     |
| -------------------- | --------- |
| Total Revenue        | ₹31.38 Cr |
| Avg Order Value      | ₹7,844    |
| Avg Discount         | 15%       |
| Return Rate          | 15%       |
| Cancellation Rate    | 33.5%     |
| Failed Payment Rate  | 33.5%     |
| Revenue at Risk      | ₹20.96 Cr |
| Net Realised Revenue | ₹10.42 Cr |

---

## 🔎 Key Business Problems Solved

### 1️⃣ Flat Revenue Across 4 Years

YoY analysis confirmed revenue remained between ₹7.77 Cr–₹7.96 Cr with category-mix shift identified as root cause.

### 2️⃣ 33.5% Cancellation Rate

Uniform across channels — identified as systemic operational issue rather than channel-specific.

### 3️⃣ Customer Churn Without Tracking

Built classification:

* Active (<90 days)
* At Risk (90–365 days)
* Churned (>365 days)

### 4️⃣ Returns Root Cause

Late delivery identified as primary driver — not product quality.

### 5️⃣ ₹20.96 Cr Revenue at Risk

Payment reconciliation showed only ₹10.42 Cr realised.

---

## 📊 Analysis Outputs

![Data Model](https://github.com/user-attachments/assets/65843e7b-0c1a-437e-aaa2-52507a019b01)

![Payment Reconciliation](https://github.com/user-attachments/assets/2dc1d6a9-a4c0-4283-aa33-579963f87957)

![Pareto Analysis](https://github.com/user-attachments/assets/dec7eb68-973c-4710-a0e8-c42b0bb141e1)

![Cancellation Rate](https://github.com/user-attachments/assets/72fcb069-6836-4611-b79e-1b0aa788383e)

![Churn Classification](https://github.com/user-attachments/assets/090de4a7-616c-4193-b8ea-9aab2572b026)

![YoY Growth](https://github.com/user-attachments/assets/aeaad99c-de0b-4691-b326-d50eec3fccb0)

---

## ⚙️ Analysis Approach

Ad-hoc validation and exploratory slicing (returns, cancellations, customer cohorts) were first performed in Excel using PivotTables before productionizing logic into scalable SQL queries.

---

## ⚙️ Production SQL Patterns Used

```sql
-- Dynamic filters
WHERE last_order_date <= DATEADD(DAY, -90, GETDATE())

-- Safe division
SUM(Sales_Amount) / NULLIF(COUNT(DISTINCT Order_ID), 0)

-- Running totals
SUM(daily_revenue) OVER (
 ORDER BY Order_Date
 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)

-- Percentile segmentation
PERCENTILE_DISC(0.90) WITHIN GROUP (ORDER BY total_revenue) OVER()
```

---

## 🛠 Tech Stack

| Tool               | Usage                                 |
| ------------------ | ------------------------------------- |
| SQL Server (T-SQL) | Core analytics queries                |
| SSMS               | Query development                     |
| Excel              | Ad-hoc validation, pivot analysis, QA |
| CTEs               | Modular business logic                |
| Window Functions   | LAG, LEAD, SUM OVER                   |
| CASE Expressions   | Segmentation                          |

---

## 📂 Files

| File                        | Description       |
| --------------------------- | ----------------- |
| consumer-goods-analysis.sql | Full SQL analysis |
| README.md                   | Documentation     |

> Source dataset confidential — not shared publicly.

---

## 👤 Author

**Avinash Dubey** — Data Analyst (≈3 YOE)

📧 [dubeyavinash157@gmail.com](mailto:dubeyavinash157@gmail.com)
🔗 LinkedIn: https://www.linkedin.com/in/avinash7007/
🌐 Portfolio: https://avinash7007.github.io/avinash-portfolio/
🐙 GitHub: https://github.com/Avinash7007

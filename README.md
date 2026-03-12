# 📊 Consumer Goods Revenue Risk & Payment Failure Analysis

An end-to-end **Consumer Goods Revenue Risk & Payment Failure Analysis** project focused on identifying revenue leakage, payment failures, cancellations, and operational inefficiencies across large-scale transactional datasets.  
This project supports stakeholders in monitoring financial performance, identifying risk drivers, and enabling data-driven recovery strategies.

---

## 📌 Business Context

Consumer goods organizations often face revenue loss due to cancellations, failed payments, returns, and operational bottlenecks.  
This project builds a structured SQL-based analytics layer to improve visibility into revenue performance, customer risk exposure, and payment realization trends.

---

## 📦 Dataset Overview

| Table         | Description                          |
| ------------- | ------------------------------------ |
| Fact_Sales    | Orders, revenue, quantity, discount  |
| Fact_Shipment | Shipment and delivery performance    |
| Fact_Returns  | Return tracking and refunds          |
| Fact_Payments | Payment status and reconciliation    |
| Dim_Customer  | Customer master data                 |
| Dim_Product   | Product hierarchy                    |
| Dim_Region    | Regional segmentation                |
| Dim_Date      | Date dimension                       |

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

## 🔎 Key Business Problems Addressed

### 1️⃣ Revenue Performance Visibility  
Identified stagnant revenue trends and key drivers across product categories and regions.

### 2️⃣ High Cancellation Rates  
Detected systemic operational issues affecting multiple channels and workflows.

### 3️⃣ Payment Failure & Revenue Leakage  
Reconciled transactions to highlight unrecovered revenue exposure.

### 4️⃣ Customer Risk Exposure  
Segmented customers based on activity patterns to identify at-risk segments.

### 5️⃣ Returns Analysis  
Identified operational and fulfillment-related drivers impacting returns.

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

Initial exploratory validation was conducted using Excel (PivotTables and QA checks), followed by scalable implementation using structured SQL logic for production-ready reporting.

---

## ⚙️ Production SQL Patterns Used

```sql
-- Dynamic filtering for recency-based analysis
WHERE last_order_date <= DATEADD(DAY, -90, GETDATE())

-- Safe division logic
SUM(Sales_Amount) / NULLIF(COUNT(DISTINCT Order_ID), 0)

-- Running totals
SUM(daily_revenue) OVER (
 ORDER BY Order_Date
 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)

-- Percentile-based segmentation
PERCENTILE_DISC(0.90) WITHIN GROUP (ORDER BY total_revenue) OVER()
```

---

## 🛠 Tech Stack

| Tool               | Usage                              |
| ------------------ | ---------------------------------- |
| SQL Server (T-SQL) | Core analytics queries             |
| SSMS               | Query development                  |
| Excel              | Validation and exploratory checks  |
| CTEs               | Modular business logic             |
| Window Functions   | Trend and cohort analysis          |
| CASE Expressions   | Customer segmentation              |

---

## 📂 Files

| File                        | Description       |
| --------------------------- | ----------------- |
| consumer-goods-analysis.sql | Full SQL analysis |
| README.md                   | Documentation     |

> Source dataset confidential — not shared publicly.

---

## 👤 Author

**Avinash Dubey — Data Analyst (≈3 YOE)**  

📧 dubeyavinash157@gmail.com  
🔗 https://www.linkedin.com/in/avinash7007/  
🌐 https://avinash7007.github.io/avinash-portfolio/  
🐙 https://github.com/Avinash7007

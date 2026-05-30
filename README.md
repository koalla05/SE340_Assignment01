# SE340_Assignment01
## Project Overview
The Banking Fraud Monitoring System is an advanced PostgreSQL-based solution designed to simulate a real-world banking fraud detection environment.
The system manages customers, accounts, cards, and transactions while automatically identifying suspicious activities through risk scoring and fraud detection rules.
**Key features include:**
* Customer, account, card, and transaction management
* Automated fraud detection and risk assessment
* Fraud alert generation
* Transaction status tracking
* Audit logging
* Analytical reporting using views
* Daily fraud dashboards using materialized views
* Automated materialized view refresh using pg_cron  

The project demonstrates advanced **PostgreSQL concepts** including:
* Constraints
* Functions
* Stored Procedures
* Triggers
* Views
* Materialized Views
* Scheduled Jobs (pg_cron)
* PL/pgSQL
## Setup Instructions
### 1. Create Database  
   ```
   CREATE DATABASE banking_fraud_system;
   Connect:
   psql -d banking_fraud_system
   ```
   
### 2. Execute Scripts
   Run scripts in the following order:
   > 01_tables.sql  
   02_sample_data.sql  
   03_functions.sql  
   04_procedures.sql  
   05_triggers.sql  
   06_views.sql  
   07_materialized_views.sql  
   
   **Example:**  
   `psql -d banking_fraud_system -f sql/01_tables.sql`

### 3. Enable pg_cron (Bonus)  
   
   **Add to PostgreSQL configuration:**
   ```
   shared_preload_libraries = 'pg_stat_statements,pg_cron'
   cron.database_name = 'banking_fraud_system'
   ```
   **Restart PostgreSQL:**  
   `brew services restart postgresql@18`

   **Enable extension:**
   `CREATE EXTENSION pg_cron;`

### 4. Schedule Dashboard Refresh
   ```
   SELECT cron.schedule(
   'fraud-dashboard-refresh',
   '0 1 * * *',
   $$REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;$$
   );
   ```
   The dashboard is refreshed daily at 01:00. 
   
## Assumptions
   Several assumptions were made during implementation:
   
   ### Risk Threshold
   Transactions with:
   `risk_score >= 70`
   are considered suspicious and are automatically flagged.
   ### High-Risk Countries
   The following countries are considered high-risk:
*    RU
*    KP
*    IR
*    SY
   ### Suspicious Merchant Categories
   The following categories increase risk:
*    CRYPTO
*    GAMBLING
*    OFFSHORE

## Transaction Approval Logic
   A transaction is:
* APPROVED if sufficient funds exist and risk score is below threshold
* FLAGGED if risk score exceeds threshold
* DECLINED if account balance is insufficient
## Account Freeze Logic
   Accounts are automatically frozen when a high-risk transaction is detected.
## Fraud Detection Logic
   Fraud detection is implemented through PostgreSQL functions, procedures, and triggers. 
## Risk Score Calculation
   Risk score is determined using multiple factors:
* Amount > 10,000              →	+30
* Amount > 50,000              →	+40
* High-risk country            →	+25
* Suspicious merchant category →	+20
* Daily volume > 100,000       →	+35  

   The final risk score is capped at: `100`
## Transaction Processing Flow
   New Transaction  
   ↓  
   Risk Score Calculation  
   ↓  
   Fraud Rule Evaluation  
   ↓  
   Status Assignment  
   ↓  
   Fraud Alert Creation  
   ↓  
   Account Freeze (if required)  
   ↓  
   Audit Logging
## Fraud Alerts
   Fraud alerts are automatically generated when:
   `risk_score >= 70`
   The alert contains:
*    transaction_id
*    fraud rule
*    reason
*    risk score
*    alert status
## Trigger Automation
   The following business processes are fully automated using triggers.
   ### Transaction Processing
   After a transaction is inserted:
*    risk score is calculated
*    transaction status is determined
   ### Fraud Alert Generation
   High-risk transactions automatically generate fraud alerts.
   ### Status History Tracking
   Every transaction status change is recorded in:
   `transaction_status_history`
   ### Audit Logging
   All INSERT, UPDATE, and DELETE operations are logged in:
   `audit_log`
   ### Customer Deletion Protection
   Customers with active accounts cannot be deleted. 
   
## Views
   The system provides several reporting views.
   - **vw_customer_accounts**  
   Customer and account information.
   - **vw_recent_transactions**  
   Transactions from the last 7 days.  
   - **vw_flagged_transactions**  
   Suspicious transactions requiring investigation.  
   - **vw_customer_risk_profile**  
   Aggregated customer risk metrics.  
## Materialized View
   `mv_daily_fraud_summary`
   Provides daily fraud monitoring statistics:
*    total transactions
*    total transaction amount
*    flagged transaction count
*    flagged transaction amount
*    average risk score
*    unique customers
*    fraud alert count
   ### Refresh:
   `REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;`
   ### Refresh Strategy
   To improve reporting performance, fraud analytics are stored in a materialized view.
   The materialized view is refreshed automatically every day using **_pg_cron_**:

   ```
   SELECT cron.schedule(
   'fraud-dashboard-refresh',
   '0 1 * * *',
   $$REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;$$
   );
   ```


   This approach avoids expensive aggregation queries on transactional tables while keeping analytical data reasonably current.
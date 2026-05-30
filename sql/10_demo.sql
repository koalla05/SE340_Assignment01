-- 1. View customer risk profiles --
SELECT *
FROM vw_customer_risk_profile
ORDER BY avg_risk_score DESC;

-- 2. Show flagged transactions --
SELECT *
FROM vw_flagged_transactions;

-- 3. Daily fraud dashboard --
SELECT *
FROM mv_daily_fraud_summary
ORDER BY transaction_date DESC;

-- 4. Most active customers --
SELECT
    customer_id,
    first_name,
    total_transactions,
    total_volume
FROM vw_customer_risk_profile
ORDER BY total_volume DESC
LIMIT 10;

-- 5. Fraud alert overview --
SELECT
    alert_status,
    COUNT(*) AS total_alerts
FROM fraud_alerts
GROUP BY alert_status;

-- 6. Transaction status history --
SELECT *
FROM transaction_status_history
ORDER BY changed_at DESC;
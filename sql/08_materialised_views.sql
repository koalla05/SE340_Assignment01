CREATE MATERIALIZED VIEW mv_daily_fraud_summary AS
SELECT
    DATE(t.transaction_at) AS transaction_date,

    COUNT(*) AS total_transactions,

    COALESCE(SUM(t.amount), 0) AS total_amount,

    COUNT(CASE WHEN t.status = 'FLAGGED' THEN 1 END) AS flagged_transactions,

    COALESCE(SUM(CASE WHEN t.status = 'FLAGGED' THEN t.amount ELSE 0 END), 0)
        AS flagged_amount,

    COALESCE(AVG(t.risk_score), 0) AS avg_risk_score,

    COUNT(DISTINCT a.customer_id) AS unique_customers,

    COUNT(f.alert_id) AS total_fraud_alerts

FROM transactions t
         JOIN accounts a
              ON t.account_id = a.account_id
         LEFT JOIN fraud_alerts f
                   ON t.transaction_id = f.transaction_id
GROUP BY DATE(t.transaction_at)
ORDER BY transaction_date;

-- test --
SELECT * FROM mv_daily_fraud_summary;
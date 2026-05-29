CREATE OR REPLACE VIEW vw_customer_accounts AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.country_code,
    a.account_id,
    a.account_number,
    a.currency,
    a.balance,
    a.status AS account_status,
    a.opened_at
FROM customers c
         JOIN accounts a
              ON c.customer_id = a.customer_id;

CREATE OR REPLACE VIEW vw_recent_transactions AS
SELECT
    t.transaction_id,
    t.account_id,
    t.amount,
    t.currency,
    t.merchant_category,
    t.merchant_country,
    t.status,
    t.risk_score,
    t.transaction_at
FROM transactions t
WHERE t.transaction_at >= NOW() - INTERVAL '7 days';

CREATE OR REPLACE VIEW vw_flagged_transactions AS
SELECT
    t.transaction_id,
    t.account_id,
    t.amount,
    t.merchant_country,
    t.merchant_category,
    t.status,
    t.risk_score,
    t.transaction_at
FROM transactions t
WHERE t.status = 'FLAGGED'
   OR t.risk_score >= 70;

CREATE OR REPLACE VIEW vw_customer_risk_profile AS
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country_code,

    COUNT(t.transaction_id) AS total_transactions,
    COALESCE(SUM(t.amount), 0) AS total_volume,
    COALESCE(AVG(t.risk_score), 0) AS avg_risk_score,

    COUNT(CASE WHEN t.status = 'FLAGGED' THEN 1 END) AS flagged_transactions,

    MAX(t.risk_score) AS max_risk_score

FROM customers c
         JOIN accounts a
              ON c.customer_id = a.customer_id
         LEFT JOIN transactions t
                   ON a.account_id = t.account_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.country_code;


-- tests --
SELECT * FROM vw_customer_accounts;
SELECT * FROM vw_recent_transactions;
SELECT * FROM vw_flagged_transactions;
SELECT * FROM vw_customer_risk_profile;
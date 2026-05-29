CREATE OR REPLACE FUNCTION calculate_customer_daily_volume(
    p_customer_id BIGINT,
    p_target_date DATE
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
AS $$
DECLARE
total_volume NUMERIC(15,2);
BEGIN
SELECT COALESCE(SUM(t.amount), 0)
INTO total_volume
FROM transactions t
         JOIN accounts a
              ON t.account_id = a.account_id
WHERE a.customer_id = p_customer_id
  AND DATE(t.transaction_at) = p_target_date
  AND t.status IN ('APPROVED', 'FLAGGED');

RETURN total_volume;
END;
$$;
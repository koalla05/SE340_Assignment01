CREATE OR REPLACE PROCEDURE create_fraud_alert(
    p_transaction_id transactions.transaction_id%TYPE,
    p_rule_id fraud_rules.rule_id%TYPE,
    p_reason TEXT,
    p_risk_score INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO fraud_alerts (transaction_id, rule_id, reason, risk_score, alert_status)
    VALUES (p_transaction_id, p_rule_id, p_reason, p_risk_score, 'OPEN');
END;
$$;

CREATE OR REPLACE PROCEDURE freeze_account(
    p_account_id accounts.account_id%TYPE
)
    LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE accounts
    SET status = 'FROZEN'
    WHERE account_id = p_account_id;

    UPDATE cards
    SET status = 'BLOCKED'
    WHERE account_id = p_account_id;
END;
$$;

CREATE OR REPLACE PROCEDURE process_transaction(
    p_transaction_id transactions.transaction_id%TYPE
)
    LANGUAGE plpgsql
AS $$
DECLARE
    v_risk_score transactions.risk_score%TYPE;
    v_account_id transactions.account_id%TYPE;
    v_amount transactions.amount%TYPE;
    v_balance accounts.balance%TYPE;

    v_country transactions.merchant_country%TYPE;
    v_category transactions.merchant_category%TYPE;
    v_customer_id accounts.customer_id%TYPE;

    v_daily_volume DECIMAL(15,2);
BEGIN
    v_risk_score := calculate_transaction_risk_score(
            p_transaction_id
                    );

    UPDATE transactions
    SET risk_score = v_risk_score
    WHERE transaction_id = p_transaction_id;

    SELECT
        t.account_id,
        t.amount,
        t.merchant_country,
        t.merchant_category,
        a.customer_id
    INTO
        v_account_id,
        v_amount,
        v_country,
        v_category,
        v_customer_id
    FROM transactions t
             JOIN accounts a
                  ON t.account_id = a.account_id
    WHERE t.transaction_id = p_transaction_id;

    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE account_id = v_account_id;

    v_daily_volume := calculate_customer_daily_volume(
            v_customer_id,
            CURRENT_DATE
                      );

    IF v_amount > 10000 THEN
        CALL create_fraud_alert(
                p_transaction_id,
                1,
                'High amount transaction detected',
                v_risk_score
             );
    END IF;

    IF is_high_risk_country(v_country) THEN
        CALL create_fraud_alert(
                p_transaction_id,
                2,
                'Transaction from high-risk country',
                v_risk_score
             );
    END IF;

    IF v_daily_volume > 100000 THEN
        CALL create_fraud_alert(
                p_transaction_id,
                3,
                'Unusual daily transaction spike detected',
                v_risk_score
             );
    END IF;

    IF v_category IN (
                      'CRYPTO',
                      'GAMBLING',
                      'OFFSHORE'
        ) THEN
        CALL create_fraud_alert(
                p_transaction_id,
                4,
                'Suspicious merchant category detected',
                v_risk_score
             );
    END IF;

    IF v_risk_score >= 70 THEN

        UPDATE transactions
        SET status = 'FLAGGED'
        WHERE transaction_id = p_transaction_id;

        CALL freeze_account(v_account_id);

    ELSIF v_balance >= v_amount THEN

        UPDATE transactions
        SET status = 'APPROVED'
        WHERE transaction_id = p_transaction_id;

        UPDATE accounts
        SET balance = balance - v_amount
        WHERE account_id = v_account_id;

    ELSE

        UPDATE transactions
        SET status = 'DECLINED'
        WHERE transaction_id = p_transaction_id;

    END IF;

END;
$$;

CREATE OR REPLACE PROCEDURE approve_pending_transactions()
    LANGUAGE plpgsql
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    FOR v_id IN
        SELECT transaction_id
        FROM transactions
        WHERE status = 'PENDING'
        LOOP -- devided not to use set-based approach as I already defined process_transaction() before --
            CALL process_transaction(v_id);
        END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE refresh_fraud_dashboard()
    LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mv_daily_fraud_summary;
END;
$$;
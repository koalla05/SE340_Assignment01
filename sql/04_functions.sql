CREATE OR REPLACE FUNCTION calculate_customer_daily_volume( -- unusual transaction activity spike
    p_customer_id customers.customer_id%TYPE,
    p_target_date transactions.transaction_at%type
)
    RETURNS DECIMAL(15,2)
    LANGUAGE plpgsql
AS $$
DECLARE
    total_volume DECIMAL(15,2);
BEGIN
    SELECT COALESCE(SUM(t.amount), 0) INTO total_volume
    FROM transactions t
             JOIN accounts a
                  ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id
      AND DATE(t.transaction_at) = p_target_date
      AND t.status IN ('APPROVED', 'FLAGGED');

    RETURN total_volume;
END;
$$;

CREATE OR REPLACE FUNCTION is_high_risk_country(
    p_country_code customers.country_code%type
)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS $$
BEGIN
    RETURN p_country_code IN (
          'RU',
          'KP',
          'IR',
          'SY'
        );
END;
$$;

CREATE OR REPLACE FUNCTION calculate_transaction_risk_score(
    p_transaction_id transactions.transaction_id%type
)
    RETURNS INT
    LANGUAGE plpgsql
AS $$
DECLARE
    v_amount transactions.amount%type;
    v_country transactions.merchant_country%type;
    v_category transactions.merchant_category%type;
    v_customer_id accounts.customer_id%type;
    v_daily_volume DECIMAL(15,2);

    risk_score transactions.risk_score%type := 0;
BEGIN
    SELECT
        t.amount,
        t.merchant_country,
        t.merchant_category,
        a.customer_id
    INTO
        v_amount,
        v_country,
        v_category,
        v_customer_id
    FROM transactions t
             JOIN accounts a
                  ON t.account_id = a.account_id
    WHERE t.transaction_id = p_transaction_id;

    -- Large transaction --
    IF v_amount > 10000 THEN
        risk_score := risk_score + 30;
        IF is_underage_customer(v_customer_id) THEN
            risk_score := risk_score + 10;
        end if;
    END IF;

    -- Very large transaction
    IF v_amount > 50000 THEN
        risk_score := risk_score + 40;
        IF is_underage_customer(v_customer_id) THEN
            risk_score := risk_score + 10;
        end if;
    END IF;

    -- High-risk country
    IF is_high_risk_country(v_country) THEN
        risk_score := risk_score + 25;
    END IF;

    -- Suspicious merchant category
    IF v_category IN (
                      'CRYPTO',
                      'GAMBLING',
                      'OFFSHORE'
        ) THEN
        risk_score := risk_score + 20;
    END IF;

    -- High daily transaction volume
    v_daily_volume := calculate_customer_daily_volume(
            v_customer_id,
            CURRENT_DATE
                      );

    IF v_daily_volume > 100000 THEN
        risk_score := risk_score + 35;
    END IF;

    IF risk_score > 100 THEN
        risk_score := 100;
    END IF;

    RETURN risk_score;
END;
$$;

CREATE OR REPLACE FUNCTION mask_card_number( -- not used --
    p_card_number BIGINT
)
    RETURNS VARCHAR
    LANGUAGE plpgsql
AS $$
BEGIN
    RETURN CONCAT(
            '****-****-****-',
            RIGHT(p_card_number, 4)
           );
END;
$$;

CREATE OR REPLACE FUNCTION get_customer_age(
    p_customer_id customers.customer_id%type
)
    RETURNS INT
    LANGUAGE plpgsql
AS $$
DECLARE
    customer_age INT;
BEGIN
    SELECT EXTRACT(YEAR FROM AGE(birth_date)) INTO customer_age
    FROM customers
    WHERE customer_id = p_customer_id;

    RETURN customer_age;
END;
$$;

CREATE OR REPLACE FUNCTION is_underage_customer(
    p_customer_id customers.customer_id%TYPE
)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS $$
DECLARE
    customer_age INT;
BEGIN
    customer_age := get_customer_age(p_customer_id);

    RETURN customer_age < 18;
END;
$$;
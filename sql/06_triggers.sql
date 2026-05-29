CREATE SEQUENCE IF NOT EXISTS seq_history_id START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS seq_audit_id   START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS seq_alert_id START 1 INCREMENT 1;

CREATE OR REPLACE FUNCTION auto_process_transaction()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    CALL process_transaction(NEW.transaction_id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_process_transaction
    AFTER INSERT ON transactions
    FOR EACH ROW
EXECUTE FUNCTION auto_process_transaction();

CREATE OR REPLACE FUNCTION track_transaction_status()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO transaction_status_history (
            history_id,
            transaction_id,
            old_status,
            new_status,
            changed_at,
            changed_by
        )
        VALUES (
                   NEXTVAL('seq_history_id'),
                   NEW.transaction_id,
                   OLD.status,
                   NEW.status,
                   CURRENT_TIMESTAMP,
                   CURRENT_USER
               );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_transaction_status_history
    AFTER UPDATE ON transactions
    FOR EACH ROW
EXECUTE FUNCTION track_transaction_status();


CREATE OR REPLACE FUNCTION audit_customers()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_log (
        audit_id,
        customer_id,
        table_name,
        operation,
        old_value,
        new_value,
        changed_at
    )
    VALUES (
               NEXTVAL('seq_audit_id'),
               COALESCE(NEW.customer_id, OLD.customer_id),
               TG_TABLE_NAME,
               TG_OP,
               to_jsonb(OLD),
               to_jsonb(NEW),
               CURRENT_TIMESTAMP
           );

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_customers_audit
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW
EXECUTE FUNCTION audit_customers();


CREATE OR REPLACE FUNCTION audit_accounts()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_log (
        audit_id,
        customer_id,
        table_name,
        operation,
        old_value,
        new_value,
        changed_at
    )
    VALUES (
               NEXTVAL('seq_audit_id'),
               COALESCE(NEW.customer_id, OLD.customer_id),
               TG_TABLE_NAME,
               TG_OP,
               to_jsonb(OLD),
               to_jsonb(NEW),
               CURRENT_TIMESTAMP
           );

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_accounts_audit
    AFTER INSERT OR UPDATE OR DELETE ON accounts
    FOR EACH ROW
EXECUTE FUNCTION audit_accounts();


CREATE OR REPLACE FUNCTION audit_transactions()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id BIGINT;
    v_account_id  BIGINT;
BEGIN
    v_account_id := COALESCE(NEW.account_id, OLD.account_id);

    SELECT customer_id INTO v_customer_id
    FROM accounts
    WHERE account_id = v_account_id;

    INSERT INTO audit_log (
        audit_id,
        customer_id,
        table_name,
        operation,
        old_value,
        new_value,
        changed_at
    )
    VALUES (
               NEXTVAL('seq_audit_id'),
               v_customer_id,
               TG_TABLE_NAME,
               TG_OP,
               to_jsonb(OLD),
               to_jsonb(NEW),
               CURRENT_TIMESTAMP
           );

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_transactions_audit
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW
EXECUTE FUNCTION audit_transactions();

CREATE OR REPLACE FUNCTION prevent_customer_delete()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
DECLARE
    active_accounts INT;
BEGIN
    SELECT COUNT(*)
    INTO active_accounts
    FROM accounts
    WHERE customer_id = OLD.customer_id
      AND status = 'ACTIVE';

    IF active_accounts > 0 THEN
        RAISE EXCEPTION
            'Cannot delete customer % — they still have % active account(s)',
            OLD.customer_id,
            active_accounts;
    END IF;

    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_prevent_customer_delete
    BEFORE DELETE ON customers
    FOR EACH ROW
EXECUTE FUNCTION prevent_customer_delete();

CREATE OR REPLACE FUNCTION apply_approved_transaction()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
DECLARE
    v_balance accounts.balance%TYPE;
BEGIN
    IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    IF NEW.status <> 'APPROVED' THEN
        RETURN NEW;
    END IF;

    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE account_id = NEW.account_id;

    IF v_balance < NEW.amount THEN
        UPDATE transactions
        SET status = 'DECLINED'
        WHERE transaction_id = NEW.transaction_id;

        RETURN NEW;
    END IF;

    UPDATE accounts
    SET balance = balance - NEW.amount
    WHERE account_id = NEW.account_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_apply_approved_transaction
    AFTER UPDATE ON transactions
    FOR EACH ROW
EXECUTE FUNCTION apply_approved_transaction();

CREATE OR REPLACE FUNCTION auto_fraud_alert_on_risk()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
DECLARE
    v_rule_id fraud_rules.rule_id%TYPE;
BEGIN
    IF OLD.risk_score IS NOT DISTINCT FROM NEW.risk_score THEN
        RETURN NEW;
    END IF;

    IF NEW.risk_score < 70 THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM fraud_alerts
        WHERE transaction_id = NEW.transaction_id
    ) THEN
        RETURN NEW;
    END IF;

    SELECT rule_id
    INTO v_rule_id
    FROM fraud_rules
    WHERE rule_type = 'RISK_SCORE'
      AND is_active = TRUE
    LIMIT 1;

    INSERT INTO fraud_alerts (
        alert_id,
        transaction_id,
        rule_id,
        reason,
        risk_score,
        alert_status,
        created_at
    )
    VALUES (
               NEXTVAL('seq_alert_id'),
               NEW.transaction_id,
               v_rule_id,
               'Risk score threshold exceeded: ' || NEW.risk_score,
               NEW.risk_score,
               'OPEN',
               CURRENT_TIMESTAMP
           );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_fraud_alert
    AFTER UPDATE ON transactions
    FOR EACH ROW
EXECUTE FUNCTION auto_fraud_alert_on_risk();
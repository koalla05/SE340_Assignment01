ALTER TABLE accounts
    ADD CONSTRAINT chk_account_status
        CHECK (
            status IN (
                       'ACTIVE',
                       'FROZEN',
                       'CLOSED'
                )
            );

ALTER TABLE accounts
    ADD CONSTRAINT chk_account_number_format
        CHECK (
            account_number ~ '^[A-Z0-9]{15,34}$' -- IBAN --
    );

ALTER TABLE cards
    ADD CONSTRAINT chk_card_status
        CHECK (
            status IN (
                       'ACTIVE',
                       'BLOCKED',
                       'EXPIRED'
                )
            );

ALTER TABLE cards
    ADD CONSTRAINT chk_card_type
        CHECK (
            card_type IN (
                          'DEBIT',
                          'CREDIT',
                          'VIRTUAL'
                )
            );

ALTER TABLE customers
    ADD CONSTRAINT chk_birth_date
        CHECK (
            birth_date <= CURRENT_DATE
            );

ALTER TABLE customers
    ADD CONSTRAINT chk_country_code
        CHECK (
            country_code ~ '^[A-Z]{2}$'
    );

ALTER TABLE transactions
    ADD CONSTRAINT chk_transaction_risk_score
        CHECK (
            risk_score >= 0
                AND risk_score <= 100
            );
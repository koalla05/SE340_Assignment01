CREATE TABLE customers (
    customer_id BIGINT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    birth_date DATE NOT NULL,
    country_code VARCHAR(2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE accounts (
    account_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    account_number VARCHAR(34) UNIQUE NOT NULL,
    currency VARCHAR(3) NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0, --  exactly 15 digits in total, two numbers after . --
    status VARCHAR(20) DEFAULT 'ACTIVE',
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_customer
      FOREIGN KEY (customer_id)
          REFERENCES customers(customer_id),

    CONSTRAINT chk_balance
      CHECK (balance >= 0),

    CONSTRAINT chk_currency
      CHECK (currency IN ('UAH', 'USD', 'EUR'))
);

CREATE TABLE cards (
    card_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    card_number_hash VARCHAR(255) UNIQUE NOT NULL,
    card_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    expiration_date DATE NOT NULL,

    CONSTRAINT fk_account
       FOREIGN KEY (account_id)
           REFERENCES accounts(account_id)
);

CREATE TABLE transactions (
    transaction_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    card_id BIGINT,
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    merchant_category VARCHAR(100),
    merchant_country CHAR(2),
    status VARCHAR(20) DEFAULT 'PENDING',
    risk_score INT DEFAULT 0,
    transaction_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_transaction_account
      FOREIGN KEY (account_id)
          REFERENCES accounts(account_id),

    CONSTRAINT fk_transaction_card
      FOREIGN KEY (card_id)
          REFERENCES cards(card_id),

    CONSTRAINT chk_amount
      CHECK (amount > 0),

    CONSTRAINT chk_transaction_currency
      CHECK (currency IN ('UAH', 'USD', 'EUR')),

    CONSTRAINT chk_transaction_status
      CHECK (
          status IN (
                     'PENDING',
                     'APPROVED',
                     'DECLINED',
                     'FLAGGED'
              )
          )
);

CREATE TABLE transaction_status_history (
    history_id BIGINT PRIMARY KEY,
    transaction_id BIGINT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) DEFAULT CURRENT_USER,

    CONSTRAINT fk_history_transaction
    FOREIGN KEY (transaction_id)
        REFERENCES transactions(transaction_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_history_status
    CHECK (
        new_status IN (
                       'PENDING',
                       'APPROVED',
                       'DECLINED',
                       'FLAGGED'
            )
        )
);

CREATE TABLE fraud_rules (
    rule_id BIGINT PRIMARY KEY,
    rule_name VARCHAR(255) NOT NULL,
    rule_type VARCHAR(100) NOT NULL,
    threshold_value INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,

    CONSTRAINT chk_threshold
     CHECK (threshold_value >= 0)
);

CREATE TABLE fraud_alerts (
    alert_id BIGINT PRIMARY KEY,
    transaction_id BIGINT NOT NULL,
    rule_id BIGINT  NOT NULL,
    reason VARCHAR(255) NOT NULL,
    risk_score INTEGER NOT NULL,
    alert_status VARCHAR(20) DEFAULT 'OPEN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_alert_transaction
      FOREIGN KEY (transaction_id)
          REFERENCES transactions(transaction_id)
          ON DELETE CASCADE,

    CONSTRAINT fk_alert_rule
      FOREIGN KEY (rule_id)
          REFERENCES fraud_rules(rule_id),

    CONSTRAINT chk_alert_status
      CHECK (
          alert_status IN (
                           'OPEN',
                           'UNDER_REVIEW',
                           'RESOLVED',
                           'FALSE_POSITIVE'
              )
          ),

    CONSTRAINT chk_alert_risk
      CHECK (
          risk_score >= 0
              AND risk_score <= 100
          )
);

CREATE TABLE audit_log (
    audit_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    old_value JSONB,
    new_value JSONB,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_customer
       FOREIGN KEY (customer_id)
           REFERENCES customers(customer_id),

    CONSTRAINT chk_operation
       CHECK (
           operation IN (
                         'INSERT',
                         'UPDATE',
                         'DELETE'
               )
           )
);
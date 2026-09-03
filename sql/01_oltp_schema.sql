\set ON_ERROR_STOP on

-- MiniPay OLTP schema
-- Порядок важен: таблицы, на которые ссылаются другие, должны быть созданы первыми.

BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(30) NOT NULL,
    last_name    VARCHAR(30) NOT NULL,
    phone        VARCHAR(20) NOT NULL,
    city         VARCHAR(30) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    status       TEXT NOT NULL CHECK (status IN ('active', 'restricted', 'blocked', 'deceased'))
);

CREATE UNIQUE INDEX IF NOT EXISTS users_active_phone_unique
    ON users (phone)
    WHERE status NOT IN ('deceased', 'blocked');

CREATE TABLE IF NOT EXISTS merchants (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    legal_name     VARCHAR(50) NOT NULL,
    displayed_name VARCHAR(50) NOT NULL,
    inn            VARCHAR(9) NOT NULL UNIQUE,
    city           VARCHAR(30) NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    status         TEXT NOT NULL CHECK (status IN ('active', 'suspended'))
);

CREATE TABLE IF NOT EXISTS cards (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id),
    last4       VARCHAR(4) NOT NULL,
    exp_month   INTEGER NOT NULL CHECK (exp_month BETWEEN 1 AND 12),
    exp_year    INTEGER NOT NULL CHECK (exp_year BETWEEN 2000 AND 2100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    status      TEXT NOT NULL CHECK (status IN ('active', 'blocked')),
    card_type   TEXT NOT NULL CHECK (card_type IN ('visa', 'mastercard', 'humo', 'uzcard'))
);

CREATE TABLE IF NOT EXISTS transactions (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sender_card_id    INTEGER NOT NULL REFERENCES cards(id),
    receiver_card_id  INTEGER REFERENCES cards(id),
    merchant_id       INTEGER REFERENCES merchants(id),
    amount            NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency          VARCHAR(3) NOT NULL,
    operation_type    TEXT NOT NULL CHECK (operation_type IN ('transfer', 'payment')),
    channel           TEXT NOT NULL CHECK (channel IN ('in_app', 'qr', 'terminal')),
    status            TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failure')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        (operation_type = 'transfer' AND channel = 'in_app')
        OR (operation_type = 'payment')
    ),
    CHECK (
        (operation_type = 'transfer' AND receiver_card_id IS NOT NULL AND merchant_id IS NULL)
        OR (operation_type = 'payment' AND merchant_id IS NOT NULL AND receiver_card_id IS NULL)
    )
);

COMMIT;

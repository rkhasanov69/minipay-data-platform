\set ON_ERROR_STOP on

BEGIN;

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.users (
    id         INTEGER NOT NULL,
    first_name VARCHAR(30) NOT NULL,
    last_name  VARCHAR(30) NOT NULL,
    phone      VARCHAR(20) NOT NULL,
    city       VARCHAR(30) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status     TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS raw.cards (
    id         INTEGER NOT NULL,
    user_id    INTEGER NOT NULL,
    last4      VARCHAR(4) NOT NULL,
    exp_month  INTEGER NOT NULL,
    exp_year   INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status     TEXT NOT NULL,
    card_type  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS raw.merchants (
    id              INTEGER NOT NULL,
    legal_name      VARCHAR(50) NOT NULL,
    displayed_name  VARCHAR(50) NOT NULL,
    inn             VARCHAR(9) NOT NULL,
    city            VARCHAR(30) NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    status          TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS raw.transactions (
    id                INTEGER NOT NULL,
    sender_card_id    INTEGER NOT NULL,
    receiver_card_id  INTEGER,
    merchant_id       INTEGER,
    amount            NUMERIC(12,2) NOT NULL,
    currency          VARCHAR(3) NOT NULL,
    operation_type    TEXT NOT NULL,
    channel           TEXT NOT NULL,
    status            TEXT NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS raw.transaction_status_history (
    id              INTEGER NOT NULL,
    transaction_id  INTEGER NOT NULL,
    status          TEXT NOT NULL,
    changed_at      TIMESTAMP WITH TIME ZONE NOT NULL
);

COMMIT;

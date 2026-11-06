CREATE TABLE fund (
    fund_id VARCHAR NOT NULL PRIMARY KEY,
    opening_cash_usd NUMBER(18, 2) NOT NULL,
    minimum_cash_usd NUMBER(18, 2) NOT NULL
);

-- A single obligation ID spans the approved instruction and its cash settlements.
CREATE TABLE cash_obligation (
    obligation_id VARCHAR NOT NULL PRIMARY KEY,
    fund_id VARCHAR NOT NULL REFERENCES fund(fund_id),
    cash_type VARCHAR NOT NULL,
    approved_on DATE NOT NULL,
    due_on DATE NOT NULL,
    units NUMBER(18, 6),
    nav_usd NUMBER(18, 6),
    fixed_amount_usd NUMBER(18, 2)
);

CREATE TABLE cash_settlement (
    settlement_id VARCHAR NOT NULL PRIMARY KEY,
    obligation_id VARCHAR NOT NULL REFERENCES cash_obligation(obligation_id),
    settled_on DATE NOT NULL,
    posted_on DATE NOT NULL,
    amount_usd NUMBER(18, 2) NOT NULL
);

CREATE TABLE business_day (
    day_number INTEGER NOT NULL PRIMARY KEY,
    business_on DATE NOT NULL UNIQUE
);

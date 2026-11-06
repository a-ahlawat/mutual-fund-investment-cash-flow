CREATE VIEW v_run AS
SELECT DATE '2025-06-30' AS as_of_on, DATE '2025-06-27' AS opening_on;

CREATE VIEW v_obligation AS
SELECT o.*,
       CASE WHEN o.cash_type IN ('SUBSCRIPTION', 'REDEMPTION')
            THEN ROUND(o.units * o.nav_usd, 2)
            ELSE o.fixed_amount_usd END AS gross_usd,
       CASE
           WHEN o.cash_type IN ('SUBSCRIPTION', 'SECURITY_SELL', 'COUPON') THEN 1
           WHEN o.cash_type IN ('REDEMPTION', 'SECURITY_BUY', 'FEE') THEN -1
       END AS direction
FROM cash_obligation AS o CROSS JOIN v_run AS r
WHERE o.approved_on <= r.as_of_on;

CREATE VIEW v_settlement AS
SELECT s.* FROM cash_settlement AS s CROSS JOIN v_run AS r
WHERE s.posted_on <= r.as_of_on AND s.settled_on <= r.as_of_on;

CREATE VIEW v_exposure AS
WITH paid AS (
    SELECT obligation_id, SUM(amount_usd) AS settled_usd
    FROM v_settlement
    GROUP BY obligation_id
)
SELECT o.*, COALESCE(p.settled_usd, 0) AS settled_usd,
       o.gross_usd - COALESCE(p.settled_usd, 0) AS open_usd
FROM v_obligation AS o LEFT JOIN paid AS p ON p.obligation_id = o.obligation_id;

CREATE VIEW v_cash_at_cutoff AS
WITH actuals AS (
    SELECT o.fund_id, SUM(s.amount_usd * o.direction) AS settled_net_usd
    FROM v_settlement AS s
    JOIN v_obligation AS o ON o.obligation_id = s.obligation_id
    CROSS JOIN v_run AS r
    WHERE s.settled_on >= r.opening_on
    GROUP BY o.fund_id
)
SELECT f.*, COALESCE(a.settled_net_usd, 0) AS settled_net_usd,
       f.opening_cash_usd + COALESCE(a.settled_net_usd, 0) AS cutoff_cash_usd
FROM fund AS f LEFT JOIN actuals AS a ON a.fund_id = f.fund_id;

CREATE VIEW v_scenario AS
SELECT 'BASE' AS scenario, 0 AS subscription_delay
UNION ALL
SELECT 'SUB_DELAY', 2;

CREATE VIEW v_forecast_event AS
WITH assigned AS (
    SELECT e.obligation_id, e.fund_id, e.cash_type, e.due_on, e.open_usd, e.direction,
           MIN(b.day_number) AS base_day_number
    FROM v_exposure AS e CROSS JOIN v_run AS r
    LEFT JOIN business_day AS b ON b.business_on > r.as_of_on AND b.business_on >= e.due_on
    WHERE e.open_usd > 0
    GROUP BY e.obligation_id, e.fund_id, e.cash_type, e.due_on, e.open_usd, e.direction
)
SELECT s.scenario, a.obligation_id, a.fund_id, a.cash_type, a.due_on,
       b.business_on AS forecast_on, a.open_usd, a.open_usd * a.direction AS signed_usd
FROM assigned AS a CROSS JOIN v_scenario AS s
LEFT JOIN business_day AS b ON b.day_number = a.base_day_number +
    CASE WHEN a.cash_type = 'SUBSCRIPTION' THEN s.subscription_delay ELSE 0 END;

CREATE VIEW v_daily_liquidity AS
WITH daily_flow AS (
    SELECT scenario, fund_id, forecast_on,
           SUM(CASE WHEN signed_usd > 0 THEN signed_usd ELSE 0 END) AS inflow_usd,
           SUM(CASE WHEN signed_usd < 0 THEN -signed_usd ELSE 0 END) AS outflow_usd
    FROM v_forecast_event
    GROUP BY scenario, fund_id, forecast_on
),
grid AS (
    SELECT s.scenario, f.fund_id, b.business_on, f.minimum_cash_usd, f.cutoff_cash_usd,
           COALESCE(d.inflow_usd, 0) AS inflow_usd, COALESCE(d.outflow_usd, 0) AS outflow_usd
    FROM v_cash_at_cutoff AS f CROSS JOIN v_scenario AS s CROSS JOIN business_day AS b
    CROSS JOIN v_run AS r
    LEFT JOIN daily_flow AS d
      ON d.scenario = s.scenario AND d.fund_id = f.fund_id AND d.forecast_on = b.business_on
    WHERE b.business_on > r.as_of_on
),
running AS (
    SELECT g.*, cutoff_cash_usd + SUM(inflow_usd - outflow_usd) OVER (
        PARTITION BY scenario, fund_id ORDER BY business_on
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS closing_cash_usd
    FROM grid AS g
)
SELECT scenario, fund_id, business_on, inflow_usd, outflow_usd, closing_cash_usd,
       minimum_cash_usd,
       CASE WHEN closing_cash_usd < minimum_cash_usd
            THEN minimum_cash_usd - closing_cash_usd ELSE 0 END AS buffer_gap_usd
FROM running;

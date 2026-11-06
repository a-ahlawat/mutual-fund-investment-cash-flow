-- Every control must return zero rows before publishing.
WITH key_counts AS (
    SELECT 'FUND' AS object_name, fund_id AS id, COUNT(*) AS copies FROM fund GROUP BY fund_id
    UNION ALL
    SELECT 'OBLIGATION', obligation_id, COUNT(*) FROM cash_obligation GROUP BY obligation_id
    UNION ALL
    SELECT 'SETTLEMENT', settlement_id, COUNT(*) FROM cash_settlement GROUP BY settlement_id
    UNION ALL
    SELECT 'CALENDAR_INDEX', CAST(day_number AS VARCHAR), COUNT(*) FROM business_day GROUP BY day_number
    UNION ALL
    SELECT 'CALENDAR_DATE', CAST(business_on AS VARCHAR), COUNT(*) FROM business_day GROUP BY business_on
)
SELECT * FROM key_counts WHERE copies <> 1;

WITH ordered_calendar AS (
    SELECT day_number, ROW_NUMBER() OVER (ORDER BY business_on) AS expected_number
    FROM business_day
)
SELECT * FROM ordered_calendar WHERE day_number <> expected_number;

SELECT f.fund_id FROM fund AS f WHERE f.minimum_cash_usd < 0;

SELECT o.obligation_id
FROM v_obligation AS o LEFT JOIN fund AS f ON f.fund_id = o.fund_id
WHERE f.fund_id IS NULL OR o.direction IS NULL OR o.gross_usd IS NULL
   OR o.gross_usd <= 0 OR o.due_on < o.approved_on
   OR (o.cash_type IN ('SUBSCRIPTION', 'REDEMPTION')
       AND (o.units <= 0 OR o.nav_usd <= 0 OR o.fixed_amount_usd IS NOT NULL))
   OR (o.cash_type NOT IN ('SUBSCRIPTION', 'REDEMPTION')
       AND (o.units IS NOT NULL OR o.nav_usd IS NOT NULL));

SELECT s.settlement_id
FROM cash_settlement AS s
LEFT JOIN cash_obligation AS o ON o.obligation_id = s.obligation_id
CROSS JOIN v_run AS r
WHERE s.posted_on <= r.as_of_on
  AND (o.obligation_id IS NULL OR s.amount_usd <= 0
       OR s.settled_on > s.posted_on OR s.settled_on < o.approved_on);

SELECT obligation_id, gross_usd, settled_usd FROM v_exposure WHERE open_usd < 0;

SELECT scenario, fund_id, obligation_id
FROM v_forecast_event
WHERE forecast_on IS NULL OR signed_usd IS NULL;

-- One forecast row per open obligation and scenario, with signed cash conserved.
WITH expected AS (
    SELECT s.scenario, e.obligation_id, e.open_usd * e.direction AS signed_usd
    FROM v_exposure AS e CROSS JOIN v_scenario AS s
    WHERE e.open_usd > 0
)
SELECT e.scenario, e.obligation_id, COUNT(f.obligation_id) AS forecast_rows
FROM expected AS e
LEFT JOIN v_forecast_event AS f
  ON f.scenario = e.scenario AND f.obligation_id = e.obligation_id
GROUP BY e.scenario, e.obligation_id, e.signed_usd
HAVING COUNT(f.obligation_id) <> 1 OR SUM(f.signed_usd) <> e.signed_usd;

-- Signed forecast events must roll up to each fund's closing cash independently.
WITH forecast_totals AS (
    SELECT scenario, fund_id, SUM(signed_usd) AS net_usd
    FROM v_forecast_event
    GROUP BY scenario, fund_id
),
last_day AS (
    SELECT MAX(business_on) AS business_on FROM business_day
)
SELECT s.scenario, f.fund_id, l.closing_cash_usd,
       f.cutoff_cash_usd + COALESCE(t.net_usd, 0) AS expected_usd
FROM v_cash_at_cutoff AS f CROSS JOIN v_scenario AS s CROSS JOIN last_day AS b
LEFT JOIN v_daily_liquidity AS l
  ON l.scenario = s.scenario AND l.fund_id = f.fund_id AND l.business_on = b.business_on
LEFT JOIN forecast_totals AS t ON t.scenario = s.scenario AND t.fund_id = f.fund_id
WHERE l.closing_cash_usd IS NULL
   OR l.closing_cash_usd <> f.cutoff_cash_usd + COALESCE(t.net_usd, 0);

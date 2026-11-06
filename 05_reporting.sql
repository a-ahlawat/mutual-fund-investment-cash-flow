SELECT fund_id, opening_cash_usd, settled_net_usd, cutoff_cash_usd
FROM v_cash_at_cutoff
ORDER BY fund_id;

SELECT scenario, fund_id, business_on, inflow_usd, outflow_usd,
       closing_cash_usd, buffer_gap_usd
FROM v_daily_liquidity
ORDER BY scenario, fund_id, business_on;

SELECT scenario, fund_id, business_on, closing_cash_usd, minimum_cash_usd, buffer_gap_usd
FROM v_daily_liquidity
WHERE buffer_gap_usd > 0
ORDER BY scenario, fund_id, business_on;

SELECT scenario, fund_id, forecast_on, obligation_id, cash_type, due_on, signed_usd
FROM v_forecast_event
ORDER BY scenario, fund_id, forecast_on, obligation_id;

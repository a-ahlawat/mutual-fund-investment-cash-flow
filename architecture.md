# Architecture decisions

## 1. Keep cash ownership at fund grain

**Decision.** Every obligation belongs to one fund. Compute cash, projections, and liquidity thresholds independently at fund level. A manager-level dashboard could count breaches or show separately labelled totals, with the fund-level detail preserved.

**Trade-off.** Fund-level balances expose a shortfall that aggregation can conceal. The demo covers USD cash only. A multi-currency extension would track cash by fund, custody account, and currency, then model conversion trades explicitly.

## 2. Project the open amount and measure settled cash separately

**Decision.** Use one obligation ID from approval to settlement. Compute the investor order amount once from locked NAV and approved units, rounding to cents. Derive flow direction from event type. Sum visible settlement magnitudes against each obligation before subtracting them. Reconcile opening cash plus signed settled flows to cutoff cash, then add the running forecast movements.

**Trade-off.** An obligation may have multiple settlements. Each synthetic settlement belongs to exactly one obligation. An aggregated custodian transfer would need a separate allocation bridge and control totals before use in this model.

**Cutoff policy.** The opening balance represents cash immediately before the start of the opening date. The cash ledger uses settlement date for timing and posting date for visibility. A settlement posted after cutoff becomes visible in a later run. An order approved after cutoff is also excluded. Preserve immutable source snapshots and run metadata if historical reruns must reproduce previously published figures.

## 3. Use a business calendar for scenario timing

**Decision.** Move overdue obligations to the first forecast business day. Schedule other obligations on the first forecast business day on or after their due date. The delay scenario then adds two business-day positions to subscriptions. An obligation outside available calendar coverage fails the release controls.

**Trade-off.** End-of-day balances are suitable for this exercise. Intraday payment sequencing, custody cutoffs, uncertainty in securities settlements, and fund-specific holidays would need more detailed timing data. The cash floor is an illustrative internal threshold. The project models cash and uses a supplied dealing NAV. Fund valuation, liquidity classification, unapproved orders, and regulatory calculations are outside scope.

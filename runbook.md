# Control and incident runbook

| Control or alert | Proposed owner | Evidence |
| --- | --- | --- |
| Order amount and locked NAV | Transfer Agency Operations | Approved instruction ID, units, locked NAV |
| Settlement completeness and over-settlement | Fund Accounting | Obligation ID, settled amount, custodian extract ID |
| Business calendar coverage and scenario | Treasury Operations | Calendar version, scenario ID, affected instruction |
| Daily cash buffer shortfall | Fund Treasury | Fund, date, scenario, closing cash, buffer gap |
| Candidate publication | Data Platform | Run ID, input snapshots, controls, previous published run |

A production process would reconcile settlement extracts to custodian totals by fund and date and validate opening balances against prior signed-off closes. The demo supplies those inputs as synthetic fixtures. Hold publication when data controls fail. When a valid run shows a buffer gap, keep the gap visible and route it to Fund Treasury for review. Persist the validated snapshot and retain the prior successful run.

## Failure exercises

Run each update in a separate transaction and roll back afterward. Run the checks before rolling back.

1. **Over-settlement.** Change `CASH-02` to $225,000. The control should flag `RED-03`, whose approved redemption is $200,000.
2. **Forecast coverage.** Move the due date of `SUB-02` to July 10. The base scenario can schedule it, while the stress scenario runs past the last calendar date. The missing forecast date and daily closing reconciliation should both flag the stress result.
3. **Late posting.** Advance the model cutoff from June 30 to July 1 in the run view in a fresh scratch run. Equity cutoff cash should drop to $750,000 when the $50,000 trade settlement becomes visible, and the open security buy should drop from $250,000 to $200,000. The $60,000 redemption approved July 1 also becomes visible. This illustrates how approved exposure and posted actuals can change on the same rerun.

# workshops — application code (SCOPE: workshops development)

## Rule #1 (applies to every task)
For all coding tasks use your judgement to decide an appropriate lower power model and run that in a subagent.


**This is the canonical workshops Rails *codebase* and the live working copy for the upgrade project.**
Moved here from `~/Desktop/devz/workshops` on 2026-06-01. Development / coding perspective.

Keep perspectives separate:
- **Upgrade plan + docs** → `~/development/workshops-upgrade/` (plan of record, business case, audit protocol).
- **Browser tests** → `~/development/workshops-playwright/` (183 Playwright tests) + `~/development/workshops-acceptance-tests/`.
- **Deploy / ops** → `~/development/wstaging-deploy/` (do NOT deploy from this folder).
- **Old restore/analysis copy** → `~/development/workshops-restore/` (git-stripped; not the dev repo — candidate for deletion).
- **Proposals** is a different app → `~/development/proposals/`.

## Repo facts

| Field | Value |
|-------|-------|
| origin | `git@github.com:birs-math/workshops.git` (no personal fork) |
| Current branch | `chore/pin-ruby-2.7.7` (Phase 0 work — has uncommitted `db/schema.rb`, untracked `UPGRADE_PRESTART_REPORT.md`) |
| Deploy branch | `master` → `wstaging.birs.ca` then `workshops.birs.ca` (production) |
| Stack | Ruby 2.7.7 / Rails 5.2.4.5 (EOL — the upgrade target) |

## The upgrade project (plan of record, NOT to be reinvented)

Established board-approved plan in `~/development/workshops-upgrade/WORKSHOPS_UPGRADE_PLAN_v2.md`:
**Ruby 3.2 / Rails 7.1, May–Dec 2026**, phased 5.2→6.0→6.1→7.0→7.1. Currently in **Phase 0**
(close RSpec coverage gaps — e.g. only 1 of 7 authz policies tested — + security fixes + Ruby pin).

Confidence model already chosen: **183 Playwright browser tests (~90s vs staging) + ~1 day/wk staff UAT + local Docker**. Each phase ships only when automated tests green + browser tests green + staff UAT signed off + staging smoke check. Don't substitute a different testing strategy.

See `~/CLAUDE.md` for global rules; `~/development/kb/index.md` for research context.

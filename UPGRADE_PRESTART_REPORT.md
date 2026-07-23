# Pre-Start Report — Workshops Ruby/Rails Upgrade

**Date:** 2026-04-22
**Branch snapshot:** fix/schedule-public-access-scraping
**Current stack:** Rails 5.2.4.5 (EOL June 2022), Ruby unpinned, webpacker 5, Bootstrap 4
**Target stack:** Rails 7.2 • Ruby 3.3 • jsbundling/esbuild • Turbo/Stimulus 3 • Bootstrap 5

This report is the gate: we do not start Phase 1 until the blocking items below are resolved.

---

## 1. Executive summary

| Area | Status | Risk |
|---|---|---|
| Test coverage | **Insufficient** — 87 specs for 15 models / 30 controllers / 7 policies / 35 services / 20 jobs / 11 mailers | 🔴 High |
| Security posture | **Active defects** — SQLi, eval() on config, no brakeman, no bundle-audit, no credentials.yml.enc | 🔴 High |
| Dependency hygiene | Ruby unpinned, 30/44 gems unpinned, node-sass/webpack4/webpacker dead upstream | 🟡 Medium |
| CI quality gates | CircleCI builds image + runs rspec; no rubocop, no brakeman, no bundle-audit, no coverage threshold | 🔴 High |
| Dev tooling | No `.rubocop.yml`, no brakeman config, no pre-commit | 🟡 Medium |
| Schema/migrations | 58 migrations, schema current (2024-04-22). OK. | 🟢 Low |
| Docs for upgrade | None. No runbook, no rollback plan. | 🟡 Medium |

**Verdict:** Do not upgrade yet. Fix test coverage gaps and security defects first (~4–6 weeks).

---

## 2. Inventory (measured)

| Category | Count | Has spec | Missing |
|---|---:|---:|---:|
| Models | 15 | 7 | **8** |
| Controllers (incl. admin, api, griddler) | 30 | 9 + 3 request = 12 | **18** |
| Policies (Pundit) | 7 | 1 | **6** |
| Jobs (incl. `app/jobs/que/`) | 20 | 15 | **5** |
| Services | 35 | 15 | **20** |
| Mailers | 11 | 7 | **4** |
| ERB templates | 157 | — (no view specs) | — |
| Feature specs (Capybara) | 28 | — | — |
| **Total spec files** | **87** | | |

### 2.1 Models missing specs (8)
`api_user`, `application_record`, `confirm_email_change`, `custom_field`, `email_notification`, `que_jobs`, `sentmail`, `setting`

### 2.2 Controllers missing specs (18)
All 7 `admin/*` controllers, `settings_controller`, `reports_controller`, `vendors_controller`, `sessions_controller`, `confirmations_controller`, `email_notifications_controller`, `registrations_controller`, `api/sessions_controller`, `api/v1/base_controller`, plus request-spec-only coverage on a few.

### 2.3 Policies missing specs (6 of 7) — highest risk
Only `event_policy_spec.rb` exists.
Missing: `default_schedule_policy`, `lecture_policy`, `membership_policy`, `schedule_policy`, `setting_policy`, `user_policy`.

Pundit policies encode authorization. Rails 7 changes nothing here per se, but a missing policy spec means silent regression risk across every rendered page.

### 2.4 Jobs missing specs (5)
`application_job`, `confirm_email_replacement_job`, `connect_to_recording_system_job`, `delete_membership_job`, `email_failed_rsvp_job`, `email_staff_schedule_notice_job`, `replace_person_job`, `que/remind_expiring_invites_job` (referenced, no spec).

### 2.5 Services missing specs (20)
Notable unspecced services on critical paths: `schedule_notice`, `setting_updater`, `pdf_template_generator`, `sync_member`, `invitation_template_selector`, `get_setting`, `upsert_email_notification`, `membership_parametizer`, `devise_fail`, `sync_members`, `participant_limits`, `sync_person`, `unlog_attachments`, `invitation_checker`, `syncable`, `email_bounce`, `membership_change_notice`, `compare_persons`, `setting_parametizer`, `invitation_email_recipients`.

### 2.6 Mailers missing specs (4)
`confirm_email_mailer`, `event_statistics_mailer`, `ws_devise_mailer`, `application_mailer`.

### 2.7 View-level coverage
**Zero view specs.** Given the Bootstrap 4→5 migration in Phase 7 will mutate all 157 ERB files, this is a major gap. Feature specs cover some UI paths but the 28 feature specs cannot assert all page states. Add view specs or rely on expanded feature specs + visual QA.

---

## 3. Security defects (found, must fix before upgrade)

### 3.1 🔴 SQL injection — `app/models/user.rb:40,45,50`
```ruby
person.memberships.where("event_id=#{event.id} AND role LIKE '%Org%'")
person.memberships.where("event_id=#{event.id} AND attendance != 'Declined'")
person.memberships.where("event_id=#{event.id} ...")
```
String interpolation of an object attribute. `event.id` is an integer so practical exploitability is low, but this is an anti-pattern brakeman would flag, and any future refactor passing a user-controlled value turns it into a real vuln. **Fix:** `where(event_id: event.id, ...)` or parameterized form.

### 3.2 🔴 `eval()` on database setting — `app/services/get_setting.rb:63,64`
```ruby
billing = eval(Setting.Locations[location]['billing_codes'])[country]
billing || eval(Setting.Locations[location]['billing_codes'])['default']
```
Evaluates a string loaded from the Setting model (DB-backed via `rails-settings-cached`). Any admin with settings write access can execute arbitrary Ruby as the Rails user. **Fix:** store billing codes as structured YAML/JSON in the setting and parse, do not `eval`.

### 3.3 🟡 68 `html_safe` / `raw` call sites
Most are wrapping static FontAwesome icon markup — safe. But a few wrap user/content-derived strings:
- `app/views/devise/registrations/new.html.erb:48` — `GetSetting.new_registration_msg.html_safe` (admin-controlled, but XSS if admin account compromised)
- `app/views/admin/application/_flashes.html.erb:17` — `value.html_safe` on flash content
- `app/views/shared/_errors.html.erb:15` — `message.html_safe` on error messages

Needs a full audit; at minimum move icon-wrapping into a helper (`icon(:calendar)`) so `html_safe` isn't sprinkled through 157 templates.

### 3.4 🟡 Extensive `.send(symbol)` on dynamic attributes
18 call sites use `send` with a symbol that originates from a model attribute, setting, or param. Examples:
- `app/models/invitation.rb:110`, `app/services/get_setting.rb:110` — `parts.first.to_i.send(parts.last)` on parsed string
- `app/models/membership.rb:293`, `app/helpers/settings_helper.rb:25` — `send(field)` where `field` comes from config
- `app/services/syncable.rb:166` — `local.send("#{k}=", v)` (constrained by `has_attribute?` — OK)

Each needs review: if the symbol is ever influenced by a param, it's an arbitrary method dispatch. **Fix:** allow-list the callable methods or switch to `public_send` with a whitelist.

### 3.5 🔴 No encrypted credentials
- `config/secrets.yml` is tracked, reading all values from ENV (OK pattern but outdated).
- No `config/credentials.yml.enc`, no `config/master.key`.
- Rails 6+ strongly prefers encrypted credentials. Migrate during Phase 2.

### 3.6 🔴 No automated security scanning
- `pronto-brakeman` is in the Gemfile dev group but brakeman itself isn't — pronto would silently no-op.
- No `bundle-audit` step in CircleCI.
- No `bundler-audit` gem.
- No `rubocop` config file despite the gem being declared.

**Fix:** add `brakeman`, `bundler-audit`, `rubocop` + `.rubocop.yml`, wire all three into CI.

### 3.7 🟡 Cookie serializer = `:json` (OK)
`config/initializers/cookies_serializer.rb` uses `:json`. Good — not Marshal. No change needed.

### 3.8 🟡 Session store = cookie
`config/initializers/session_store.rb` uses `:cookie_store`. With `activerecord-session_store` also in the Gemfile but unused (?). Audit: either remove the gem or switch to `:active_record_store` if sessions need server-side invalidation (recommended for an auth-heavy app).

---

## 4. Dependency defects

| Issue | Impact |
|---|---|
| No `.ruby-version`, no `ruby` in Gemfile, no RUBY VERSION in lock | Dev/prod drift, CI non-deterministic |
| 30 of 44 gems unpinned (loose or no version) | `bundle update` can silently break prod |
| `rails '~> 5.2.4.5'` — EOL since 2022-06 | Security patches stopped |
| `psych '~> 3.3.2'` pin | Blocks Ruby 3.1+ |
| `rails-settings-cached 0.7.2` (from 2018) — current is 2.9 | API-breaking migration needed for Phase 5 |
| `dry-configurable '~> 0.9.0'` — current 1.2 | |
| `sqlite3 '~> 1.3.6'` — test-only, current 2.x | |
| `webpacker '~> 5.x'` — retired 2022 | Must replace in Phase 5 |
| `coffee-rails`, `jquery-rails`, `turbolinks`, `jquery-turbolinks`, `uglifier` — all superseded | Remove in Phase 5 |
| `node-sass ^6.0.1` — deprecated 2020 | Replace with dartsass |
| `webpack 4.46` — webpack 5 + esbuild path preferred | Phase 5 swap |
| `font-awesome-rails` — last release 2020 | npm `@fortawesome/fontawesome-free` |
| `momentjs-rails` — moment in maintenance mode | Replace with dayjs or Intl |
| `wkhtmltopdf-binary` — unmaintained, multiple CVEs | Replace with Grover/Chromium in Phase 8 |
| `sucker_punch` coexists with `que` | Redundant; audit usages, pick one |
| `popper_js` standalone gem | Will be replaced by BS5 npm deps |

---

## 5. CI / quality gates (defects)

| Gate | Present? | Needed for upgrade |
|---|---|---|
| Build Docker image | ✅ | |
| Run RSpec | ✅ | |
| Coverage measurement (SimpleCov) | Declared in Gemfile, threshold not enforced | ❌ Set min 80% line |
| Coverage report published | ✅ Codacy | |
| Brakeman | ❌ | ❌ Add |
| bundle-audit | ❌ | ❌ Add |
| RuboCop | Gem present, no config, not in CI | ❌ Add `.rubocop.yml`, run in CI |
| Deprecation-warnings-as-errors | ❌ | ❌ Add `ActiveSupport::Deprecation.behavior = :raise` in test env |
| Branch protection on master | ? | Verify in GitHub settings |
| Required reviews | ? | Verify |
| Ruby version matrix | ❌ | Add 2.7 → 3.0 → 3.1 → 3.2 → 3.3 progression |

---

## 6. Operational defects

- **No rollback runbook.** If Phase 2 (Rails 6.0 Zeitwerk) ships and breaks prod, there's no documented procedure beyond `cap production deploy:rollback`.
- **No staging parity check.** wstaging.birs.ca exists but there's no automated diff of gem versions / schema between staging and production.
- **No smoke-test checklist.** Manual QA today is ad-hoc.
- **Docker base image version not pinned to patch** in Dockerfile (verify separately).

---

## 7. Blocking items (must resolve before Phase 1 starts)

Sorted by priority. Each is a PR or PR series.

### P0 — security (do first, ~1 week)
1. Fix SQLi in `user.rb:40,45,50` → parameterized `where`.
2. Replace `eval` in `get_setting.rb:63,64` → structured setting + JSON parse.
3. Add `brakeman`, `bundler-audit` to Gemfile + CI; fail CI on any HIGH finding.
4. Migrate `config/secrets.yml` → `config/credentials.yml.enc` with master key in env.
5. Audit `html_safe` / `raw` in `admin/_flashes`, `shared/_errors`, `devise/registrations/new` — escape or sanitize.

### P1 — test coverage (~3–4 weeks)
Target: ≥90% line on models/policies/services, ≥80% on controllers, feature-spec coverage on every smoke path.

1. **Policy specs (6 missing).** Highest ROI. Full (action × role) matrix.
2. **Model specs (8 missing).** Validations, associations, scopes, callbacks.
3. **Controller request specs (18 missing).** Happy + unauthorized + not-found per action.
4. **Service specs (20 missing).** Pure-Ruby, fastest to write.
5. **Job specs (5 missing).** Including retry/failure paths.
6. **Mailer specs (4 missing).** Body + headers + attachment round-trip.
7. **Feature specs for Bootstrap-4→5 risk surface.** Add coverage for every page type that will be touched visually: login, event edit, membership edit, schedule CRUD, RSVP, admin dashboards, reports, settings.
8. **Characterization tests** for the `.send` and `html_safe` call sites — pin current behavior so Rails 7 or BS5 don't silently change rendering.

### P2 — infra (~1 week)
1. Pin Ruby: `.ruby-version` = `2.7.8` (current target before Phase 1), add `ruby '2.7.8'` to Gemfile.
2. Lock bundler: `bundle lock --add-platform` for CI platforms.
3. `.rubocop.yml` with rails + rspec cops, enforce in CI.
4. Turn `ActiveSupport::Deprecation.behavior = :raise` in test env.
5. Add SimpleCov threshold (start at current baseline, raise after P1).
6. Write **UPGRADE_RUNBOOK.md** per phase: pre-flight checks, deploy steps, smoke suite, rollback.
7. Write **SMOKE_CHECKLIST.md** — the 15–20 flows that must pass in staging after every phase.
8. Snapshot production DB schema + seed data fixtures for upgrade-rehearsal environments.

---

## 8. Proposed Phase 0 schedule (5–6 weeks)

| Week | Workstream A (security) | Workstream B (tests) | Workstream C (infra) |
|---|---|---|---|
| 1 | SQLi + eval fixes, brakeman in CI | Policy specs (all 6) | `.ruby-version`, rubocop config |
| 2 | Credentials migration, html_safe audit | Model specs (8) | SimpleCov threshold, deprecation=raise |
| 3 | `.send` allowlist audit | Controller request specs (first 10) | Runbook + smoke checklist |
| 4 | | Controller specs (last 8), service specs (first 10) | Staging parity check |
| 5 | | Service specs (last 10), job + mailer specs | Fixtures for upgrade env |
| 6 | Dress rehearsal: full suite + smoke on staging | | Sign-off gate |

Exit gate (all must hold):
- [ ] Brakeman CI step: 0 high, 0 medium findings
- [ ] bundle-audit CI step: 0 CVEs
- [ ] SimpleCov ≥ 85% line coverage overall, ≥ 95% on `app/policies/`
- [ ] 10 consecutive green CI runs, no flakes
- [ ] SMOKE_CHECKLIST.md manually run on staging, fully green
- [ ] UPGRADE_RUNBOOK.md reviewed and signed off
- [ ] Rollback tested on staging

Only after this gate does Phase 1 (Ruby 2.7 pin) begin.

---

## 9. Open questions

1. Is there a staging-production schema drift? Unknown until we compare.
2. Is `activerecord-session_store` actually used, or dead weight?
3. Is `sucker_punch` actually used alongside Que?
4. Does `GetSetting.new_registration_msg` allow HTML today — who can edit it?
5. Does production have `config/credentials.yml.enc` already? (Only `config/secrets.yml` is in git; env-based setup implies no.)
6. What's the real traffic pattern — is a rolling deploy safe, or must we maintenance-window each phase?
7. Are there any clients / integrations consuming the `api/v1/*` endpoints that lock the response format?

Answer these before signing off Phase 0.

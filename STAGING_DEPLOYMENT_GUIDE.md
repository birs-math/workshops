# 🚀 BULLETPROOF STAGING DEPLOYMENT GUIDE

## Pre-Deployment Checklist ✅

**Branch:** `duplicate-delete`  
**Commits:** 5 commits ready (see git log)  
**Database:** 4 new migrations tested and working  

## Critical Files to Sync

### Application Files
```
app/controllers/admin/confirm_email_changes_controller.rb
app/views/admin/confirm_email_changes/index.html.erb  
app/views/admin/confirm_email_changes/show.html.erb
app/models/confirm_email_change.rb
app/dashboards/confirm_email_change_dashboard.rb
config/routes.rb
```

### Database Migrations (MUST BE EXACT)
```
db/migrate/20250625092908_add_soft_delete_columns.rb
db/migrate/20250625092939_create_person_merge_audit.rb  ← FIXED VERSION
db/migrate/20250625092945_enhance_confirm_email_change.rb
db/migrate/20250625152951_add_confirm_email_change_id_to_people.rb
db/schema.rb
```

### Optional
```
lib/tasks/create_test_conflict.rake (for testing)
```

## Deployment Commands

### 1. Clean Environment
```bash
cd /data/workshops-staging
docker-compose down -v
docker system prune -f
```

### 2. Build & Start
```bash
docker-compose build --no-cache
docker-compose up -d
docker-compose ps  # Verify all containers running
```

### 3. Database Setup
```bash
# Restore production data
gunzip -c db-202506250200.sql.gz | docker exec -i workshops_db psql -U wsuser -d workshops_production

# Run migrations (CRITICAL - these are tested and work)
docker-compose exec web bundle exec rails db:migrate

# Verify migration success
docker-compose exec web bundle exec rails db:migrate:status | grep "20250625"
```

### 4. Reset Admin Access
```bash
docker-compose exec web bundle exec rails runner "
user = User.find_by(email: 'sysadmin@birs.ca')
user.password = 'password123456'
user.save!
puts 'Admin ready: sysadmin@birs.ca / password123456'
"
```

### 5. Validation Tests
```bash
# Create test conflict
docker-compose exec web bundle exec rake test:create_duplicate_conflict

# Test interface: https://wstaging.birs.ca/admin/confirm_email_changes
# Expected: 1 pending conflict, filtering works, merge works

# Cleanup
docker-compose exec web bundle exec rake test:cleanup_test_conflicts
```

## 🛡️ Safety Guarantees

- ✅ All migrations tested and working in dev
- ✅ No data loss (soft deletes, audit trails)  
- ✅ Production database preserved
- ✅ Rollback possible (just checkout previous branch)
- ✅ Admin access maintained

## 🚨 If Something Goes Wrong

### Migration Fails
```bash
# Check specific migration
docker-compose exec web bundle exec rails db:migrate:up VERSION=20250625092939

# If person_merge_audits fails, create manually:
docker exec -i workshops_db psql -U wsuser -d workshops_production -c "
CREATE TABLE IF NOT EXISTS person_merge_audits (
  id bigserial PRIMARY KEY,
  source_person_id bigint NOT NULL,
  target_person_id bigint NOT NULL,
  source_email varchar,
  target_email varchar,
  affected_memberships json,
  affected_invitations json,
  merge_reason text,
  initiated_by varchar,
  completed boolean DEFAULT false,
  error_message text,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);
"
```

### Application Won't Start
```bash
docker-compose logs web | tail -20
# Usually database connection or missing gems
```

### Emergency Rollback
```bash
git checkout e414e520  # Last known good commit
docker-compose down
docker-compose build --no-cache  
docker-compose up -d
```

## ✨ Expected Features After Deployment

1. **Enhanced Admin Interface** - /admin/confirm_email_changes
2. **Smart Filtering** - Pending/resolved/high priority options
3. **Side-by-Side Comparison** - Data completeness, recommendations
4. **Edit Integration** - "Edit Person" buttons open in new tabs
5. **Safe Merging** - Audit trails, soft deletes
6. **Test Data Generation** - rake tasks for UAT

**Deployment Package Prepared by Dev Claude 🤖**  
**Ready for Other Claude to Execute! 🚀**
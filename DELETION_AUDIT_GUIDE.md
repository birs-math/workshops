# 🕵️ Conflict Deletion Audit Trail Guide

## How to Track Deleted Conflicts

When staff delete conflict records, the system now creates a complete audit trail.

### Automatic Tracking

Every deletion now logs:
- **Who** deleted it (admin user email)
- **When** it was deleted (timestamp)
- **What** was deleted (conflict details, person names, emails)
- **Why** (marked as "CONFLICT RECORD DELETED")

### Example Deletion Message

```
Deleted conflict #1234: Person 52415 (missing) ↔ Adrián Gonzalez Casanova (gonzalez.casanova@berkeley.edu) - Deleted by sysadmin@birs.ca
```

## Viewing Audit Trail

### Recent Deletions Only
```bash
docker-compose exec web bundle exec rake audit:show_deletions
```

### Complete Audit Trail (Merges + Deletions)
```bash
docker-compose exec web bundle exec rake audit:show_all
```

### Search Rails Logs
```bash
docker-compose logs web | grep "CONFLICT DELETION"
```

## Database Query

Direct database access to audit records:
```sql
SELECT 
  created_at,
  initiated_by,
  merge_reason,
  source_email,
  source_person_id,
  target_person_id
FROM person_merge_audits 
WHERE merge_reason LIKE 'CONFLICT RECORD DELETED%' 
ORDER BY created_at DESC;
```

## What Gets Tracked

✅ **User who deleted** - `initiated_by` field  
✅ **Timestamp** - `created_at` field  
✅ **Conflict details** - Person IDs, names, emails  
✅ **Deletion reason** - Stored in `merge_reason`  
✅ **Rails logs** - Searchable log entries with 🗑️ emoji  

## Use Cases

- **Accountability**: Who deleted what and when
- **Data recovery**: Identify what was lost
- **Pattern analysis**: Find frequent deletion reasons
- **Compliance**: Audit trail for data governance

## Example Output

```
🔍 Recent Conflict Deletion Audit Trail
==================================================

📅 2025-06-25 14:30
👤 Deleted by: sysadmin@birs.ca
🗑️  CONFLICT RECORD DELETED - Person 52415 (missing) ↔ Adrián Gonzalez Casanova
📧 Email: gonzalez.casanova@berkeley.edu
ID: Source=52415, Target=67890
----------------------------------------

📅 2025-06-25 13:15
👤 Deleted by: staff@birs.ca  
🗑️  CONFLICT RECORD DELETED - John Smith ↔ J. Smith
📧 Email: j.smith@university.edu
ID: Source=11111, Target=22222
----------------------------------------

📊 Total deletions found: 2
```

**Never lose track of deletions again!** 🎯
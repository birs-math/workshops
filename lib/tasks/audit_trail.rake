namespace :audit do
  desc "Show recent conflict deletion audit trail"
  task show_deletions: :environment do
    puts "🔍 Recent Conflict Deletion Audit Trail"
    puts "=" * 50
    
    # Get deletion audit records (last 50)
    deletions = PersonMergeAudit.where("merge_reason LIKE ?", "CONFLICT RECORD DELETED%")
                               .order(created_at: :desc)
                               .limit(50)
    
    if deletions.any?
      deletions.each do |audit|
        puts "\n📅 #{audit.created_at.strftime('%Y-%m-%d %H:%M')}"
        puts "👤 Deleted by: #{audit.initiated_by}"
        puts "🗑️  #{audit.merge_reason}"
        puts "📧 Email: #{audit.source_email}"
        puts "ID: Source=#{audit.source_person_id}, Target=#{audit.target_person_id}"
        puts "-" * 40
      end
      
      puts "\n📊 Total deletions found: #{deletions.count}"
    else
      puts "No deletion records found."
    end
  end
  
  desc "Show all merge audit trail (merges + deletions)"
  task show_all: :environment do
    puts "🔍 Complete Merge & Deletion Audit Trail"
    puts "=" * 50
    
    audits = PersonMergeAudit.order(created_at: :desc).limit(100)
    
    audits.each do |audit|
      action = audit.merge_reason.include?("DELETED") ? "🗑️  DELETED" : "🔄 MERGED"
      puts "\n📅 #{audit.created_at.strftime('%Y-%m-%d %H:%M')} | #{action}"
      puts "👤 By: #{audit.initiated_by}"
      puts "📧 #{audit.source_email} → #{audit.target_email}"
      puts "🆔 Person #{audit.source_person_id} → Person #{audit.target_person_id}"
      puts "📝 #{audit.merge_reason}"
      puts "-" * 40
    end
    
    puts "\n📊 Total audit records: #{audits.count}"
  end
end
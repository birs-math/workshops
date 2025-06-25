namespace :test do
  desc "Create test persons and simulate email conflict for UAT"
  task create_duplicate_conflict: :environment do
    puts "Creating test scenario for duplicate email conflict..."
    
    # Create first person with unique email
    person1 = Person.create!(
      firstname: 'John',
      lastname: 'Smith',
      email: 'john.smith@university-a.edu',
      affiliation: 'University A',
      title: 'Professor',
      phone: '555-1234',
      address1: '123 Main St',
      city: 'Boston',
      region: 'MA',
      country: 'USA',
      academic_status: 'Faculty',
      phd_year: '2010',
      updated_by: 'test_task'
    )
    
    puts "Created Person 1: #{person1.name} (ID: #{person1.id}) - #{person1.email}"
    
    # Create second person with different email initially
    person2 = Person.create!(
      firstname: 'Mike',
      lastname: 'Johnson',
      email: 'mike.johnson@university-b.edu',
      affiliation: 'University B - Department of Mathematics',
      title: 'Dr.',
      phone: '555-5678',
      address1: '456 Oak Avenue',
      city: 'Cambridge',
      region: 'MA',
      country: 'USA',
      academic_status: 'Professor',
      phd_year: '2005',
      updated_by: 'test_task'
    )
    
    puts "Created Person 2: #{person2.name} (ID: #{person2.id}) - #{person2.email}"
    
    # Now simulate email change that will create conflict
    puts "Simulating email change that will create a conflict..."
    sync_service = SyncPerson.new(person2, person1.email)
    
    # This will trigger conflict creation since names don't match
    result = sync_service.change_email
    
    if result.errors.any?
      puts "❌ Error occurred: #{result.errors.full_messages}"
    else
      puts "✅ Test conflict scenario created!"
      puts "Person 2 (#{person2.name}) tried to change email to #{person1.email}"
      puts "This should create a conflict since names don't match"
      puts "Navigate to /admin/confirm_email_changes to see the new pending conflict"
    end
  end
  
  desc "Clean up test conflict data"
  task cleanup_test_conflicts: :environment do
    puts "Cleaning up test conflicts..."
    
    # Remove test persons by email patterns
    test_emails = ['john.smith@university-a.edu', 'mike.johnson@university-b.edu']
    test_persons = Person.where(email: test_emails)
    test_person_ids = test_persons.pluck(:id)
    
    # Remove related conflicts
    ConfirmEmailChange.where(replace_person_id: test_person_ids).destroy_all
    ConfirmEmailChange.where(replace_with_id: test_person_ids).destroy_all
    
    # Remove test persons
    test_persons.destroy_all
    
    puts "✅ Test data cleaned up!"
  end
end
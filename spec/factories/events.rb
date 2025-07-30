# spec/factories/events.rb
require 'factory_bot_rails'
require 'faker'

FactoryBot.define do
  # Define sequences for different number lengths based on production codes
  sequence(:event_number_4_digits) { |n| n.to_s.rjust(4, '0') } # For YYwNNNN
  sequence(:event_number_3_digits) { |n| n.to_s.rjust(3, '0') } # For YYritNNN, YYfrgNNN, YYssNNN

  sequence(:start_date, 1) do |n|
    n = 1 if n > 48 # avoid going years into the future
    date = Time.zone.today.beginning_of_year.advance(weeks: 1)
    date.advance(weeks: n).beginning_of_week(:sunday)
  end

  sequence(:end_date, 1) do |n|
    n = 1 if n > 48
    date = Time.zone.today.beginning_of_year.advance(weeks: 1)
    date.advance(weeks: n, days: 5)
  end

  factory :event do |f|
    # Default attributes
    f.state { 'active' }
    f.name { Faker::Lorem.sentence(word_count: 4) }
    f.short_name { Faker::Lorem.sentence(word_count: 1) }
    f.booking_code { 'Booking' }
    f.door_code { 1234 }
    f.start_date
    f.end_date
    # Default to 'Workshop' - will generate a 'w' code unless overridden by a trait
    f.event_type { 'Workshop' }
    f.event_format { ['Physical', 'Online', 'Hybrid'].sample }
    f.location { 'EO' }
    f.max_participants { GetSetting.max_participants(location) rescue 42 }
    f.max_virtual { GetSetting.max_virtual(location) rescue 300 }
    f.max_observers { GetSetting.max_observers(location) rescue 10 }
    f.time_zone { 'Mountain Time (US & Canada)' }
    f.description { Faker::Lorem.sentence(word_count: 6) }
    f.updated_by { 'FactoryBot' }
    f.template { false }

    # Transients for date manipulation
    transient do
      past { false }
      future { false }
      current { false }
    end

    # After build callback to set dates and generate the code based on event_type
    after(:build) do |event, evaluator|
      # --- Date Setting Logic (same as before) ---
      date = Time.zone.today
      date = date + 3.weeks if date.month == 1
      if evaluator.past
        date = date.prev_year
        event.start_date = date.prev_week(:sunday)
      elsif evaluator.future
        date = date.next_year
        event.start_date = date.next_week(:sunday)
      elsif evaluator.current
        weekends = %w(Friday Saturday Sunday)
        if date.strftime("%A").match(Regexp.union(weekends))
          event.start_date = date.beginning_of_week(:friday)
        else
          event.start_date = date.beginning_of_week(:sunday)
        end
      end
      event.end_date = event.start_date + 5.days unless event.start_date.nil?
      # --- End Date Setting Logic ---

      # --- Code Generation Logic (Updated) ---
      if event.start_date.present?
        year_prefix = event.start_date.strftime('%y')

        # Determine code structure based on event_type attribute
        case event.event_type
        when 'Research in Teams'
          event.code = "#{year_prefix}rit#{generate(:event_number_3_digits)}"
        # Ensure this string matches exactly what your model/validation expects for 'frg'
        when 'Focused Research Group'
          event.code = "#{year_prefix}frg#{generate(:event_number_3_digits)}"
        when 'Summer School'
          event.code = "#{year_prefix}ss#{generate(:event_number_3_digits)}"
        when 'Workshop' # Handle the default case
          event.code = "#{year_prefix}w#{generate(:event_number_4_digits)}"
        else
          # Fallback for any unexpected event types - maybe default to Workshop?
          # Or raise an error: raise "Unknown event_type for code generation: #{event.event_type}"
          Rails.logger.warn "FactoryBot: Unknown event_type '#{event.event_type}' for code generation, defaulting to Workshop format."
          event.code = "#{year_prefix}w#{generate(:event_number_4_digits)}"
        end
      else
        # Fallback if start_date is missing (use 'w' format as default)
        event.code = "00w#{generate(:event_number_4_digits)}"
      end
      # --- End Code Generation Logic ---
    end

    # --- Traits for Specific Event Types ---
    trait :research_in_teams do
      event_type { 'Research in Teams' }
    end

    trait :focused_research_group do
      # Use the exact string expected by your application for 'frg' type
      event_type { 'Focused Research Group' }
    end

    trait :summer_school do
      event_type { 'Summer School' }
    end
    # --- End Traits ---

    # --- Child Factories (No changes needed here unless they require specific event types) ---
    factory :event_with_roles do
      max_observers { 10 }
      after(:create) do |event|
        create(:membership, role: 'Contact Organizer', event: event, arrival_date: event.start_date, departure_date: event.end_date)
        create(:membership, role: 'Organizer', event: event, arrival_date: event.start_date, departure_date: event.end_date)
        create(:membership, role: 'Participant', event: event, arrival_date: event.start_date, departure_date: event.end_date)
        create(:membership, role: 'Observer', event: event, arrival_date: event.start_date, departure_date: event.end_date)
        create(:membership, role: 'Virtual Participant', event: event) if event.event_format != 'Physical'
      end
    end

    factory :event_with_members do
      max_observers { 10 }
      after(:create) do |event|
        arrival = event.start_date
        departure = event.end_date
        create(:membership, role: 'Contact Organizer', event: event, arrival_date: arrival, departure_date: departure)
        create(:membership, role: 'Organizer', event: event, arrival_date: arrival, departure_date: departure)
        create(:membership, role: 'Observer', event: event, attendance: 'Confirmed', arrival_date: arrival, departure_date: departure)
        create(:membership, role: 'Observer', event: event, attendance: 'Not Yet Invited')
        3.times { create(:membership, role: 'Participant', event: event, attendance: 'Confirmed', arrival_date: arrival, departure_date: departure) }
        create(:membership, role: 'Participant', event: event, attendance: 'Not Yet Invited')
        create(:membership, role: 'Participant', event: event, attendance: 'Invited')
        create(:membership, role: 'Participant', event: event, attendance: 'Undecided')
        # Note: 'Backup Participant' might not be in Event::ROLES - check if valid
        create(:membership, role: 'Backup Participant', event: event, attendance: 'Not Yet Invited')
        create(:membership, role: 'Participant', event: event, attendance: 'Declined')
        # Creates a 'Participant' with 'Confirmed' status (previously corrected)
        create(:membership, role: 'Participant', event: event, attendance: 'Confirmed', arrival_date: arrival, departure_date: departure)
      end
    end

    factory :event_with_schedule do
      after(:create) do |event|
        9.upto(12) do |t|
          create(:schedule, event: event, name: "Item at #{t}",
               start_time: (event.start_date + 2.days).in_time_zone(event.time_zone).change({ hour: t }),
               end_time: (event.start_date + 2.days).in_time_zone(event.time_zone).change({ hour: t + 1 }))
        end
      end
    end
    # --- End Child Factories ---

  end # End of factory :event
end
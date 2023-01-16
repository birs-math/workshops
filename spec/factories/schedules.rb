require 'factory_bot_rails'

FactoryBot.define do
  factory :schedule do |f|
    event { association :event }

    f.name { 'FactoryBot reserves a spot on the schedule!' }
    f.location { association :location }
    f.description { Faker::Lorem.sentence(word_count: 4) }
    f.updated_by { 'FactoryBot' }
    f.start_time { (event.start_date + 1.days).in_time_zone(event.time_zone).change({ hour: 9, min: 0 }) }
    f.end_time { (event.start_date + 1.days).in_time_zone(event.time_zone).change({ hour: 10, min: 0 }) }
  end
end


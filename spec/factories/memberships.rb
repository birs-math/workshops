require 'factory_bot_rails'

FactoryBot.define do
  require 'faker'

  factory :membership do |f|
    association :person, factory: :person
    association :event, factory: :event, future: true

    f.role { 'Participant' }
    f.attendance { 'Confirmed' }
    f.replied_at { Faker::Date.backward(days: 14) }
    f.billing { %w[ABC DEF GHI].sample }
    f.room { 'ROOM' + Random.rand(0..1000).to_s }
    f.stay_id { Faker::Lorem.words(number: 1) }
    f.has_guest { %w[true false].sample }
    f.num_guests { 0 }
    f.own_accommodation { %w[true false].sample }
    f.guest_disclaimer { true }
    f.reviewed { true }
    f.special_info { Faker::Lorem.sentence(word_count: 1) }
    f.staff_notes { Faker::Lorem.sentence(word_count: 1) }
    f.org_notes { Faker::Lorem.sentence(word_count: 1) }
    f.updated_by { 'FactoryBot' }

    trait :stub_for_report do
      arrival_date { '2023-01-20' }
      departure_date { '2023-01-25' }
      has_guest { true }
      num_guests { 1 }
      billing { 'BIRS' }
      special_info { 'I need a mic!' }
      org_notes { 'Bring bottles of water' }
    end
  end
end

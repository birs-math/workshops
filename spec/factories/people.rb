# spec/factories/people.rb
require 'factory_bot_rails'
require 'faker'

FactoryBot.define do
  factory :person do
    sequence(:firstname) { |n| "#{n}-#{Faker::Name.first_name}" }
    sequence(:lastname) { |n| "#{n}-#{Faker::Name.last_name}" }
    sequence(:email) { |n| "person-#{n}@#{Faker::Internet.domain_name}" }
    sequence(:legacy_id) { |n| Random.rand(1000..9999) }
    
    salutation { 'Prof.' }
    gender { %w[M F].sample }
    url { Faker::Internet.url }
    phone { Faker::PhoneNumber.phone_number }
    affiliation { Faker::University.name }
    department { Faker::Commerce.department }
    academic_status { 'Professor' }
    address1 { Faker::Address.street_address }
    city { Faker::Address.city }
    postal_code { Faker::Address.postcode }
    region { Faker::Address.state }
    country { Faker::Address.country }
    biography { Faker::Lorem.paragraph }
    research_areas { Faker::Lorem.words(number: 4).join(', ') }
    grants { [] }
    updated_by { 'FactoryBot' }
    
    trait :stub_for_report do
      firstname { 'John' }
      lastname { 'Doe' }
      affiliation { 'Test case' }
      department { 'IT' }
      academic_status { 'PHD' }
      phd_year { 0 }
      gender { 'M' }
      research_areas { 'cyber security' }
      title { 'Dr.' }
      grants { 'some NSERC grant' }
    end
  end
end
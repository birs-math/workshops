require 'factory_bot_rails'
require 'faker'

FactoryBot.define do
  factory :user do
    association :person
    
    # Generate a password and use it for both fields
    password = Faker::Internet.password(min_length: 12)
    
    email { Faker::Internet.email }
    password { password }
    password_confirmation { password }
    confirmed_at { Time.now }
    location { 'EO' }
    role { 'member' }
    jti { SecureRandom.uuid }
    
    trait :staff do
      role { 'staff' }
    end
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :super_admin do
      role { 'super_admin' }
    end
  end
end
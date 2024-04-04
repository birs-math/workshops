FactoryBot.define do
  factory :custom_field do |f|
    f.title { Faker::Lorem.sentence }
    f.description { Faker::Lorem.paragraph }
    f.position { (1..10).to_a.sample }
    f.value { Faker::Lorem.sentence }
  end
end

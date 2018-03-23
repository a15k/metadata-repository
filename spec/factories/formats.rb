FactoryBot.define do
  factory :format do
    name        { Faker::Lorem.words.join(' ') }
    description { Faker::Lorem.words.join(' ') }
  end
end

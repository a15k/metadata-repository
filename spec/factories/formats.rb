FactoryBot.define do
  factory :format do
    name        { Faker::Lorem.word }
    description { Faker::Lorem.words.join(' ') }
  end
end

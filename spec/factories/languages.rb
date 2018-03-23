FactoryBot.define do
  factory :language do
    name    { Faker::Lorem.word }
    pg_name { Faker::Lorem.word }
  end
end

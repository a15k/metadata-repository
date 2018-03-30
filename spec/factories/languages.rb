FactoryBot.define do
  factory :language do
    name    { Faker::Lorem.words.join(' ') }
  end
end

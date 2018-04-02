FactoryBot.define do
  factory :language do
    name    { Faker::Lorem.words(10).join(' ') }
  end
end

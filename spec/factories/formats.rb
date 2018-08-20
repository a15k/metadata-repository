FactoryBot.define do
  factory :format do
    name          { Faker::Lorem.words(10).join(' ') }
    specification { Faker::Lorem.words(10).join(' ') }
  end
end

FactoryBot.define do
  factory :application do
    uuid { SecureRandom.uuid }
    name { Faker::Lorem.words.join(' ') }
  end
end

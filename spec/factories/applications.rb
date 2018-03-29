FactoryBot.define do
  factory :application do
    uuid  { SecureRandom.uuid }
    name  { Faker::Lorem.words.join(' ') }
    token { SecureRandom.hex(32) }
  end
end

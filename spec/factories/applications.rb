FactoryBot.define do
  factory :application do
    uuid { SecureRandom.uuid }
  end
end

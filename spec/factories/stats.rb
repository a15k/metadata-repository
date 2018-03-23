FactoryBot.define do
  factory :stats do
    application
    user
    resource
    format
    uuid  { SecureRandom.uuid }
    value { {} }
  end
end

FactoryBot.define do
  factory :metadata do
    application
    user
    resource
    format
    uuid  { SecureRandom.uuid }
    value { {} }
  end
end

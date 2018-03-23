FactoryBot.define do
  factory :stats do
    application
    application_user
    resource
    format
    uuid  { SecureRandom.uuid }
    value { { 'test': true } }
  end
end

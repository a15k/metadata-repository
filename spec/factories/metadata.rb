FactoryBot.define do
  factory :metadata do
    application
    application_user
    resource
    format
    uuid  { SecureRandom.uuid }
    value { { 'test': true } }
  end
end

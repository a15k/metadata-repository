FactoryBot.define do
  factory :stats do
    resource
    application_user
    application      { application_user.application }
    format
    uuid             { SecureRandom.uuid }
    value            { { 'test': true } }
  end
end

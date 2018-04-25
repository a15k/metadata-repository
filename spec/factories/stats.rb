FactoryBot.define do
  factory :stats do
    resource
    application_user
    application      { application_user.application }
    format
    language
    uuid             { SecureRandom.uuid }
    value            { { 'test': true } }
  end
end

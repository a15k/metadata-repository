FactoryBot.define do
  factory :metadata do
    resource
    application_user
    application      { application_user.application }
    format
    uuid             { SecureRandom.uuid }
    value            { { 'test': true } }
  end
end

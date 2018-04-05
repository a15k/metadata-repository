FactoryBot.define do
  factory :resource do
    application_user
    application   { application_user.application }
    format
    language
    uuid          { SecureRandom.uuid }
    uri           { "https://example.com/assessments/#{uuid}" }
    resource_type 'assessment'
    content       { Faker::Lorem.words(10).join(' ') }
  end
end

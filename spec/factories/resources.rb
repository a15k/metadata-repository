FactoryBot.define do
  factory :resource do
    application
    application_user
    format
    language
    uuid    { SecureRandom.uuid }
    uri     { Faker::Internet.url }
    type    'assessment'
    content { Faker::Lorem.words }
    tsvector ''
  end
end

FactoryBot.define do
  factory :resource do
    application
    application_user
    format
    language
    uuid          { SecureRandom.uuid }
    uri           { Faker::Internet.url }
    resource_type 'assessment'
    content       { Faker::Lorem.words.join(' ') }
  end
end

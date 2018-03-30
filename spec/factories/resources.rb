FactoryBot.define do
  factory :resource do
    application_user
    application   { application_user.application }
    format
    language
    uuid          { SecureRandom.uuid }
    uri           { Faker::Internet.url }
    resource_type 'assessment'
    content       { Faker::Lorem.words.join(' ') }
  end
end

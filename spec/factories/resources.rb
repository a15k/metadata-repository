FactoryBot.define do
  factory :resource do
    application
    user
    format
    language
    uuid    { SecureRandom.uuid }
    uri     { Faker::Internet.url }
    version { Faker::App.version }
    type    'assessment'
    content { Faker::Lorem.words }
  end
end

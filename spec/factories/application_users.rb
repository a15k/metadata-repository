FactoryBot.define do
  factory :application_user do
    uuid { SecureRandom.uuid }
    application
  end
end

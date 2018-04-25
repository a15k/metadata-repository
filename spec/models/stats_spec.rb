require 'rails_helper'

RSpec.describe Stats, type: :model do
  subject(:stats) { FactoryBot.create :stats }

  it { is_expected.to belong_to(:application) }
  it { is_expected.to belong_to(:application_user) }
  it { is_expected.to belong_to(:resource) }
  it { is_expected.to belong_to(:format) }
  it { is_expected.to belong_to(:language) }

  it { is_expected.to validate_presence_of(:uuid) }
  it { is_expected.to validate_presence_of(:value) }

  it { is_expected.to validate_uniqueness_of(:uuid).scoped_to(:application_id).case_insensitive }
end

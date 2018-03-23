require 'rails_helper'

RSpec.describe ApplicationUser, type: :model do
  subject(:application_user) { FactoryBot.create :application_user }

  it { is_expected.to have_many(:resources) }
  it { is_expected.to have_many(:metadatas) }
  it { is_expected.to have_many(:stats) }

  it { is_expected.to belong_to(:application) }

  it { is_expected.to validate_presence_of(:uuid) }

  it { is_expected.to validate_uniqueness_of(:uuid).scoped_to(:application_id).case_insensitive }
end

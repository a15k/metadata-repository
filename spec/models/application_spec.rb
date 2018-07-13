require 'rails_helper'

RSpec.describe Application, type: :model do
  subject(:application) { FactoryBot.create :application }

  it { is_expected.to have_many(:application_users).dependent(:destroy) }
  it { is_expected.to have_many(:resources).dependent(:destroy) }
  it { is_expected.to have_many(:metadatas).dependent(:destroy) }
  it { is_expected.to have_many(:stats).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:uuid) }

  it { is_expected.to validate_uniqueness_of(:uuid).case_insensitive }
end

require 'rails_helper'

RSpec.describe Format, type: :model do
  subject(:format) { FactoryBot.create :format }

  it { is_expected.to have_many(:resources).dependent(:destroy) }
  it { is_expected.to have_many(:metadatas).dependent(:destroy) }
  it { is_expected.to have_many(:stats).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
end

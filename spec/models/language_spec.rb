require 'rails_helper'

RSpec.describe Language, type: :model do
  subject(:language) { FactoryBot.create :language }

  it { is_expected.to have_many(:resources) }

  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
end

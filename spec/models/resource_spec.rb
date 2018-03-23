require 'rails_helper'
require 'vcr_helper'

RSpec.describe Resource, type: :model, vcr: VCR_OPTS do
  subject(:resource) { FactoryBot.create :resource }

  it { is_expected.to have_many(:metadatas).dependent(:destroy) }
  it { is_expected.to have_many(:stats).dependent(:destroy) }

  it { is_expected.to belong_to(:application) }
  it { is_expected.to belong_to(:application_user) }
  it { is_expected.to belong_to(:format) }
  it { is_expected.to belong_to(:language) }

  it { is_expected.to validate_presence_of(:uuid) }
  it { is_expected.to validate_presence_of(:uri) }
  it { is_expected.to validate_presence_of(:type) }

  it { is_expected.to validate_uniqueness_of(:uuid).scoped_to(:application_id).case_insensitive }
  it { is_expected.to validate_uniqueness_of(:uri).scoped_to(:application_id) }

  context '#set_content' do
    it 'can fetch content from a remote resource and follow redirects' do
      resource.uri = 'http://exercises.openstax.org/api/exercises/1000'
      resource.content = nil
      resource.save!

      expect(resource.content).not_to be_blank
    end
  end
end

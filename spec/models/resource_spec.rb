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
  it { is_expected.to validate_presence_of(:resource_type) }

  it { is_expected.to validate_uniqueness_of(:uuid).scoped_to(:application_id).case_insensitive }
  it { is_expected.to validate_uniqueness_of(:uri).scoped_to(:application_id) }

  context '.search' do
    before(:all) do
      DatabaseCleaner.start

      simple  = FactoryBot.create :language, name: 'simple'
      english = FactoryBot.create :language, name: 'english'

      all_queries = [ 'lorem', 'jumps', 'jump' ]
      resources = 10.times.map { FactoryBot.create :resource, language: simple }.each do |resource|
        resource.destroy if all_queries.any? do |query|
          resource.content.downcase.include?(query) || (
            !resource.title.nil? && resource.title.downcase.include?(query)
          )
        end
      end

      @title_resource = FactoryBot.create(
        :resource, title: 'Lorem Ipsum', content: 'None', language: simple
      )
      @content_resource = FactoryBot.create(
        :resource, title: nil, content: 'Lorem Ipsum', language: simple
      )
      @both_resource = FactoryBot.create(
        :resource, title: 'Lorem Ipsum', content: 'Lorem Ipsum', language: simple
      )
      @fox_and_dog_resource = FactoryBot.create(
        :resource, title: 'The fox and the dog',
                   content: 'The quick brown fox jumps over the lazy dog.',
                   language: english
      )
    end
    after(:all)  { DatabaseCleaner.clean }

    it 'returns Resources matching the given query, ordered by relevance' do
      expect(Resource.search(query: 'lorem')).to(
        eq [ @both_resource, @title_resource, @content_resource ]
      )
    end

    it 'can use dictionaries for specific languages' do
      # "jumps" is normalized to "jump" by the english dictionary
      expect(Resource.search(query: 'jumps')).to eq []
      expect(Resource.search(query: 'jumps', language: 'english')).to eq [ @fox_and_dog_resource ]

      expect(Resource.search(query: 'jump')).to eq [ @fox_and_dog_resource ]
      expect(Resource.search(query: 'jump', language: 'english')).to eq [ @fox_and_dog_resource ]
    end

    it "defaults to 'simple' dictionary if the given language is invalid" do
      expect(Resource.search(query: 'lorem', language: 'abc')).to eq Resource.search(query: 'lorem')
      expect(Resource.search(query: 'jumps', language: '123')).to eq Resource.search(query: 'jumps')
    end

    it 'can return results in a specific order' do
      expect(Resource.search(query: 'lorem', order_by: 'created_at,id')).to(
        eq [ @title_resource, @content_resource, @both_resource ]
      )

      expect(Resource.search(query: 'lorem', order_by: '-created_at,id')).to(
        eq [ @both_resource, @content_resource, @title_resource ]
      )
    end

    it 'can highlight the query terms within the original text' do
      expect(Resource.search(query: 'lorem').with_pg_search_highlight.map(&:highlight)).to eq [
        '<b>Lorem</b> Ipsum <b>Lorem</b> Ipsum', '<b>Lorem</b> Ipsum None', '<b>Lorem</b> Ipsum'
      ]

      expect(
        Resource.search(query: 'jump', language: 'english').with_pg_search_highlight.first.highlight
      ).to eq '&hellip; quick brown fox <b>jumps</b> over the lazy &hellip;'
    end
  end

  context '#set_content' do
    it 'can fetch content from a remote resource and follow redirects' do
      resource.uri = 'http://exercises.openstax.org/api/exercises/1000'
      resource.content = nil
      resource.save!

      expect(resource.content).not_to be_blank
    end
  end
end

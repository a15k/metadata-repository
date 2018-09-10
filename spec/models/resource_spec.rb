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
    before       { Resource::SEARCH_CACHE.clear }

    it 'returns Resources matching the given query, ordered by relevance' do
      expect(Resource.search(query: 'lorem')).to eq(
        SearchResults.new([ @both_resource, @title_resource, @content_resource ], 3)
      )
    end

    it 'can use dictionaries for specific languages' do
      # "jumps" is normalized to "jump" by the english dictionary
      expect(Resource.search(query: 'jumps')).to eq SearchResults.new([], 0)
      expect(Resource.search(query: 'jumps', language: 'english')).to eq(
        SearchResults.new([ @fox_and_dog_resource ], 1)
      )

      expect(Resource.search(query: 'jump')).to eq SearchResults.new([ @fox_and_dog_resource ], 1)
      expect(Resource.search(query: 'jump', language: 'english')).to eq(
        SearchResults.new([ @fox_and_dog_resource ], 1)
      )
    end

    it "defaults to 'simple' dictionary if the given language is invalid" do
      expect(Resource.search(query: 'lorem', language: 'abc')).to eq Resource.search(query: 'lorem')
      expect(Resource.search(query: 'jumps', language: '123')).to eq Resource.search(query: 'jumps')
    end

    it 'can return results in a specific order' do
      expect(Resource.search(query: 'lorem', order_by: 'created_at,id')).to eq(
        SearchResults.new([ @title_resource, @content_resource, @both_resource ], 3)
      )

      expect(Resource.search(query: 'lorem', order_by: '-created_at,id')).to eq(
        SearchResults.new([ @both_resource, @content_resource, @title_resource ], 3)
      )
    end

    it 'can paginate the results' do
      expect(Resource.search(query: 'lorem', page: 0, per_page: 0)).to eq SearchResults.new([], 0)
      expect(Resource.search(query: 'lorem', page: 1, per_page: 0)).to eq SearchResults.new([], 0)

      expect(Resource.search(query: 'lorem', order_by: 'created_at,id', page: 0, per_page: 1)).to(
        eq SearchResults.new([], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: 'created_at,id', page: 1, per_page: 1)).to(
        eq SearchResults.new([ @title_resource ], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: 'created_at,id', page: 2, per_page: 1)).to(
        eq SearchResults.new([ @content_resource ], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: 'created_at,id', page: 3, per_page: 1)).to(
        eq SearchResults.new([ @both_resource ], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: 'created_at,id', page: 4, per_page: 1)).to(
        eq SearchResults.new([], 3)
      )

      expect(Resource.search(query: 'lorem', order_by: '-created_at,id', page: 0, per_page: 2)).to(
        eq SearchResults.new([], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: '-created_at,id', page: 1, per_page: 2)).to(
        eq SearchResults.new([ @both_resource, @content_resource ], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: '-created_at,id', page: 2, per_page: 2)).to(
        eq SearchResults.new([ @title_resource ], 3)
      )
      expect(Resource.search(query: 'lorem', order_by: '-created_at,id', page: 3, per_page: 2)).to(
        eq SearchResults.new([], 3)
      )
    end

    it 'can highlight the query terms within the original text' do
      expect(Resource.search(query: 'lorem').items.map(&:headline)).to eq [
        '<b>Lorem</b> Ipsum <b>Lorem</b> Ipsum', '<b>Lorem</b> Ipsum None', '<b>Lorem</b> Ipsum'
      ]

      expect(
        Resource.search(query: 'jump', language: 'english').items.first.headline
      ).to eq '&hellip; quick brown fox <b>jumps</b> over the lazy &hellip;'
    end

    it 'can search by metadatas and stats' do
      FactoryBot.create :metadata, resource: @fox_and_dog_resource,
                                   value: { book: 'Intro to Learning' }
      FactoryBot.create :metadata, resource: @both_resource,
                                   value: { book: 'Intro to Learning' }

      expect(Resource.search(query: 'learning jumps')).to eq(
        SearchResults.new([ @fox_and_dog_resource ], 1)
      )

      FactoryBot.create :stats, resource: @title_resource, value: { students: 'Few' }
      FactoryBot.create :stats, resource: @both_resource,  value: { students: 'Many' }

      expect(Resource.search(query: 'many lorem')).to eq SearchResults.new([ @both_resource ], 1)
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

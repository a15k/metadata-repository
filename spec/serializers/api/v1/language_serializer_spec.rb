require 'rails_helper'

RSpec.describe Api::V1::LanguageSerializer, type: :serializer do
  let(:language)          { FactoryBot.create :language }
  let(:options)           { {} }
  subject(:serializer)    { described_class.new(language, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize language attributes' do
    expect(data_hash[:id]).to eq language.name
    expect(data_hash[:type]).to eq :language
    expect(data_hash[:attributes]).to eq name: language.name
  end
end

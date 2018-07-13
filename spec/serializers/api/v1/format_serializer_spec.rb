require 'rails_helper'

RSpec.describe Api::V1::FormatSerializer, type: :serializer do
  let(:format)            { FactoryBot.create :format }
  let(:options)           { {} }
  subject(:serializer)    { described_class.new(format, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize format attributes' do
    expect(data_hash[:id]).to eq format.name
    expect(data_hash[:type]).to eq :format
    expect(data_hash[:attributes]).to be_nil
  end
end

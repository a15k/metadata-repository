require 'rails_helper'

RSpec.describe Api::V1::ApplicationSerializer, type: :serializer do
  let(:application)       { FactoryBot.create :application }
  let(:options)           { {} }
  subject(:serializer)    { described_class.new(application, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize application attributes' do
    expect(data_hash[:id]).to eq application.uuid
    expect(data_hash[:type]).to eq :application
    expect(data_hash[:attributes]).to eq name: application.name
  end
end

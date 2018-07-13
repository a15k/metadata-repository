require 'rails_helper'

RSpec.describe Api::V1::MetadataSerializer, type: :serializer do
  let(:metadata)          { FactoryBot.create :metadata }
  let(:options)           { { include: [ :application, :application_user, :resource, :format ] } }
  subject(:serializer)    { described_class.new(metadata, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize metadata attributes' do
    expect(data_hash[:id]).to eq metadata.uuid
    expect(data_hash[:type]).to eq :metadata
    expect(data_hash[:attributes]).to eq value: metadata.value
  end

  it 'can serialize metadata relationships' do
    expect(data_hash[:relationships][:application][:data]).to eq(
      { id: metadata.application_uuid, type: :application }
    )
    expect(data_hash[:relationships][:application_user][:data]).to eq(
      { id: metadata.application_user_uuid, type: :application_user }
    )
    expect(data_hash[:relationships][:resource][:data]).to eq(
      { id: metadata.resource_uuid, type: :resource }
    )
    expect(data_hash[:relationships][:format][:data]).to eq(
      { id: metadata.format_name, type: :format }
    )
  end
end

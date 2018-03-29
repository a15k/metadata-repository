require 'rails_helper'

RSpec.describe Api::V1::StatsSerializer, type: :serializer do
  let(:stats)             { FactoryBot.create :stats }
  let(:options)           { { include: [ :application, :application_user, :resource, :format ] } }
  subject(:serializer)    { described_class.new(stats, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize stats attributes' do
    expect(data_hash[:id]).to eq stats.uuid
    expect(data_hash[:type]).to eq :stats
    expect(data_hash[:attributes]).to eq stats.attributes.symbolize_keys.slice(:uuid, :value)
  end

  it 'can serialize stats relationships' do
    expect(data_hash[:relationships][:application][:data]).to eq(
      { id: stats.application_uuid, type: :application }
    )
    expect(data_hash[:relationships][:application_user][:data]).to eq(
      { id: stats.application_user_uuid, type: :application_user }
    )
    expect(data_hash[:relationships][:resource][:data]).to eq(
      { id: stats.resource_uuid, type: :resource }
    )
    expect(data_hash[:relationships][:format][:data]).to eq(
      { id: stats.format_name, type: :format }
    )
  end
end

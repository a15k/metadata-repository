require 'rails_helper'

RSpec.describe Api::V1::ResourceSerializer, type: :serializer do
  let(:resource)          { FactoryBot.create :resource }
  let(:options)           { { include: [ :application, :application_user, :format, :language ] } }
  subject(:serializer)    { described_class.new(resource, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize resource attributes' do
    expect(data_hash[:id]).to eq resource.uuid
    expect(data_hash[:type]).to eq :resource
    expect(data_hash[:attributes]).to eq(
      resource.attributes.symbolize_keys.slice(:uri, :resource_type, :title, :content)
                                        .merge(highlight: nil)
    )
  end

  it 'can serialize resource relationships' do
    expect(data_hash[:relationships][:application][:data]).to eq(
      { id: resource.application_uuid, type: :application }
    )
    expect(data_hash[:relationships][:application_user][:data]).to eq(
      { id: resource.application_user_uuid, type: :application_user }
    )
    expect(data_hash[:relationships][:format][:data]).to eq(
      { id: resource.format_name, type: :format }
    )
    expect(data_hash[:relationships][:language][:data]).to eq(
      { id: resource.language_name, type: :language }
    )
  end
end

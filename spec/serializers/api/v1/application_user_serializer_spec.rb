require 'rails_helper'

RSpec.describe Api::V1::ApplicationUserSerializer, type: :serializer do
  let(:application_user)  { FactoryBot.create :application_user }
  let(:options)           { {} }
  subject(:serializer)    { described_class.new(application_user, options) }
  let(:serializable_hash) { serializer.serializable_hash }
  let(:data_hash)         { serializable_hash[:data] }

  it 'can serialize application_user attributes' do
    expect(data_hash[:id]).to eq application_user.uuid
    expect(data_hash[:type]).to eq :application_user
    expect(data_hash[:attributes]).to be_nil
  end

  it 'can serialize application_user relationships' do
    expect(data_hash[:relationships][:application][:data]).to eq(
      { id: application_user.application_uuid, type: :application }
    )
  end
end

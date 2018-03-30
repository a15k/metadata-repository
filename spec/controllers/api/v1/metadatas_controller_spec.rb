require 'rails_helper'

RSpec.describe Api::V1::MetadatasController, type: :controller do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
  end

  include_examples 'json api controller errors',
                   params_proc: -> { { resource_uuid: @resource.uuid } },
                   api_token_proc: -> { @application.token }

end

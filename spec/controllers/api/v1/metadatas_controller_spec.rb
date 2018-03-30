require 'rails_helper'

RSpec.describe Api::V1::MetadatasController, type: :controller do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
  end

  include_examples 'json api controller errors',
                   extra_params_proc: -> { { resource_uuid: @resource.uuid } },
                   application_proc: -> { @application }

end

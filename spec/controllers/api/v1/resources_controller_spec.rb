require 'rails_helper'

RSpec.describe Api::V1::ResourcesController, type: :controller do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
  end

  include_examples 'json api controller errors', collection_actions: [
    [ :get   , :index   ],
    [ :post  , :create  ],
    [ :get   , :search  ],
    [ :post  , :search  ]
  ]

  context '#index' do
    xit 'returns all resources created by the current application' do
      get :index, format: :json
    end
  end
end

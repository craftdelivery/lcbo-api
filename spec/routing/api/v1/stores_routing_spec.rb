require 'rails_helper'

RSpec.describe 'V1 Store resources routing', type: :routing do
  it 'routes /stores' do
    expect(get '/stores').to route_to(
      controller: 'api/v1/stores',
      action:     'index')
  end

  it 'routes /stores/:id' do
    expect(get '/stores/511').to route_to(
      controller: 'api/v1/stores',
      action:     'show',
      id:         '511')
  end

  it 'routes /products/:product_id/stores' do
    expect(get '/products/18/stores').to route_to(
      controller: 'api/v1/stores',
      action:     'index',
      product_id: '18')
  end
end

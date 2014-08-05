class API::V2::StoresQuery < Magiq::Query
  model { Store }

  has_pagination

  param :include_dead, type: :bool
  apply do
    scope.where(is_dead: false) unless params[:include_dead]
  end

  equal :id, type: :id, alias: :ids, array: true

  order \
    :id,
    :distance_in_meters,
    :inventory_volume_in_milliliters,
    :products_count,
    :inventory_count,
    :inventory_price_in_cents

  bool \
    :has_wheelchair_accessability,
    :has_bilingual_services,
    :has_product_consultant,
    :has_tasting_bar,
    :has_beer_cold_room,
    :has_special_occasion_permits,
    :has_vintages_corner,
    :has_parking,
    :has_transit_access

  range :distance_in_meters,              type: :whole
  range :inventory_volume_in_milliliters, type: :whole
  range :products_count,                  type: :whole
  range :inventory_count,                 type: :whole
  range :inventory_price_in_cents,        type: :whole

  param :product_id, type: :id
  apply :product_id do |product_id|
    scope.joins(:inventories).
      select('stores.*, inventories.quantity, inventories.reported_on').
      where('inventories.product_id' => product.id)
  end

  param :product_ids, type: :id, array: true, limit: 10
  apply :product_ids do |ids|
    scope.with_product_ids(ids)
  end

  exclusive :product_id, :product_ids

  def product
    @product ||= begin
      if (id = params[:product_id])
        Product.find(id)
      else
        nil
      end
    end
  end

  param :lat, type: :latitude
  param :lon, type: :longitude
  apply :lat, :lon do |lat, lon|
    scope.distance_from(lat, lon)
  end

  param :q, type: :string
  apply :q do |q|
    scope.search(q)
  end

  param :geo
  apply :geo do |geo|
    loc = GEO[geo].first.geometry.location
    scope.distance_from(loc.lat, loc.lng)
  end

  mutual [:lat, :lon], exclusive: :geo
end
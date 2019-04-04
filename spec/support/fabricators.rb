Fabricator(:crawl_event) do
  level      'info'
  message    'This is a log message'
  payload    key: 'value'
  created_at Time.at(1293645823)
end

Fabricator(:crawl) do
  state                                         'finished'
  task                                          'final_task'
  total_products                                10
  total_stores                                  10
  total_inventories                             100
  total_product_inventory_count                 1000
  total_product_inventory_volume_in_milliliters 100000
  total_product_inventory_price_in_cents        100000
  total_jobs                                    1000
  total_finished_jobs                           1000
  store_ids                                     [1, 2, 3]
  product_ids                                   [1, 2, 3]
  added_product_ids                             [2000, 2001, 2002]
  added_store_ids                               [200, 201, 202]
  removed_product_ids                           [1000, 1001, 1002]
  removed_store_ids                             [100, 101, 102]
  created_at                                    Time.at(1293645823)
  updated_at                                    Time.at(1293645823)
end

Fabricator(:product) do
  crawl_id                            1
  name                                'Floris Ninkeberry Gardenbeer'
  price_in_cents                      250
  regular_price_in_cents              250
  limited_time_offer_savings_in_cents 0
  limited_time_offer_ends_on          nil
  bonus_reward_miles                  nil
  bonus_reward_miles_ends_on          nil
  alcohol_content                     350
  sugar_content                       '8'
  package                             '330 mL bottle'
  package_unit_type                   'bottle'
  package_unit_volume_in_milliliters  330
  total_package_units                 1
  total_package_volume_in_milliliters 330
  inventory_count                     1000
  inventory_volume_in_milliliters     330000
  inventory_price_in_cents            25000
  origin                              'Belgium'
  producer_name                       'Brouwerij Huyghe'
  released_on                         '2010-10-10'
  stock_type                          'LCBO'
  primary_category                    'Beer'
  secondary_category                  'Ale'
  has_bonus_reward_miles              false
  has_limited_time_offer              false
  is_vqa                              false
  is_discontinued                     true
  is_seasonal                         false
  description                         'A beer that is a beerish color'
  tasting_note                        'Tastes like beer'
  serving_suggestion                  'Serve chilled'
  created_at                          Time.at(1293645823)
  updated_at                          Time.at(1293645823)

  after_build do |product|
    product.tags = product.name.split.map(&:downcase).join(' ')
    product.save
  end
end

Fabricator(:store) do
  crawl_id                        1
  name                            'Street Avenue'
  address_line_1                  '2356 Kennedy Road'
  address_line_2                  'Agincourt Mall'
  city                            'Toronto-Scarborough'
  postal_code                     'M1T3H1'
  telephone                       '(416) 291-5304'
  fax                             '(416) 291-0246'
  latitude                        43.7838
  longitude                       -79.2902
  has_parking                     true
  has_transit_access              true
  has_wheelchair_accessability    true
  has_bilingual_services          false
  has_product_consultant          false
  has_tasting_bar                 true
  has_beer_cold_room              false
  has_special_occasion_permits    true
  has_vintages_corner             true
  monday_open                     600
  monday_close                    1320
  tuesday_open                    600
  tuesday_close                   1320
  wednesday_open                  600
  wednesday_close                 1320
  thursday_open                   600
  thursday_close                  1320
  friday_open                     600
  friday_close                    1320
  saturday_open                   600
  saturday_close                  1320
  sunday_open                     720
  sunday_close                    1020
  products_count                  50
  inventory_count                 1000
  inventory_price_in_cents        1000000
  inventory_volume_in_milliliters 1000000
  created_at                      Time.at(1293645823)
  updated_at                      Time.at(1293645823)

  after_build do |store|
    store.tags = store.name.split.map(&:downcase).join(' ')
    store.set_latlonrad
    store.save
  end
end

Fabricator(:inventory) do
  store_id    1
  product_id  1
  crawl_id    1
  quantity    100
  reported_on Date.new(2010, 10, 10)
  created_at  Time.at(1293645823)
  updated_at  Time.at(1293645823)
end


Fabricator(:producer) do
  name 'Producer Co.'
  lcbo_ref 'producer-co'
  is_dead false
  is_ocb false
end

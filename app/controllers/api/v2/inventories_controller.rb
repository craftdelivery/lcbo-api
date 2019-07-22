class API::V2::InventoriesController < API::V2::APIController
  
  def index
    data  = {}
    query = API::V2::InventoriesQuery.new(params)
    scope = query.to_scope

    data[:data] = scope.map { |i| serialize(i, params) }

    if (pagination = pagination_for(scope))
      data[:meta] = pagination
    end

    render_json(data)
  end

  def onestore
    render_json(Inventory.where(store_id: params[:store_id], is_dead: false))
  end
  
  def stores
    ids = JSON.parse(params[:store_ids])
    # render_json(ids)
    puts ids
    render_json(Inventory.where(store_id: ids), is_dead: false)
  end
  
  def show
    data      = {}
    pid, sid  = *Magiq::Types.lookup(:inventory_id).cast(params[:id])
    inventory = Inventory.where(product_id: pid, store_id: sid).first!

    data[:data] = serialize(inventory, include_dead: true)

    render_json(data)
  end

  private

  def serialize(inventory, scope = nil)
    API::V2::InventorySerializer.new(inventory,
      scope: scope || params
    ).as_json(root: false)
  end
end

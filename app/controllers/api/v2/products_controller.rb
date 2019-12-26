class API::V2::ProductsController < API::V2::APIController
  def index
    data    = {}
    query   = API::V2::ProductsQuery.new(params)
    scope   = query.to_scope
    results = scope.load
    data[:data] = results.map { |p| serialize(p, params) }
    puts 'GETTING PRODUCTS NO PAGINATION'
    # if (pagination = pagination_for(scope))
    #   data[:meta] = pagination
    # end
    # data[:meta]['foo'] = {foo: 'bar'}
    if data[:data].empty? && params[:q].present?
      data[:meta] ||= {}
      data[:meta][:search_suggestions] = [Fuzz[:products, params[:q]]]
    end
    render_json(data)
  end

  def all
    render_json(Product.all)
  end

  def show
    data    = {}
    product = Product.find(params[:id])
    data[:data] = serialize(product, include_dead: true)
    render_json(data)
  end

  def clean(str)
    if !str.nil? && str.kind_of?(String)
      s = str.gsub("'", '')
      s.gsub(/\s/, ' ')
    else
      return ''
    end
  end

  def desc
    data = {}
    body = JSON.parse(request.body.read())
    ids = body['ids']
    products = Product.find(ids).map { |product| {
      description: clean(product.tasting_note),
      servingsuggestion: clean(product.serving_suggestion),
      lcboid: product.id,
      released: clean(product.released_on)
    }}
    render_json(products)
  end

  def img
    images = Product.all.pluck(:id, :image_url, :image_thumb_url)
    render_json(images)
  end

  def cheap
    products = Product
      .where(:primary_category=>"Beer")
      .where.not("producer_name like ?", "%Saké%")
      .where.not("producer_name like ?", "%Sake%")
      .where.not("name like ?", "%Sake%")
      .where.not("primary_category like ?", "%Sake%")
      .where.not(:secondary_category=>"Sake")
      .where.not("name like ?", "%Saké%")
      .where.not("primary_category like ?", "%Saké%")
      .where.not(:secondary_category=>"Saké")
      .where("price_per_liter_in_cents > ?",0)
      .where.not(:is_discontinued=>true)
      .where("alcohol_content > ?", 100)
      .where.not(:is_dead=>true)
      .order(:price_per_liter_in_cents)
      .select("id, name, price_per_liter_in_cents, price_in_cents, regular_price_in_cents, volume_in_milliliters, alcohol_content, primary_category, secondary_category, producer_name, updated_at")
    render_json(products)
  end

  private

  def serialize(product, scope = nil)
    API::V2::ProductSerializer.new(product,
      scope: scope || params
    ).as_json(root: false)
  end
end

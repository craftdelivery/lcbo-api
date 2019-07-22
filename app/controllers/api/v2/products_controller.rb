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

  private

  def serialize(product, scope = nil)
    API::V2::ProductSerializer.new(product,
      scope: scope || params
    ).as_json(root: false)
  end
end

class API::V1::DatasetsController < API::V1::APIController
  def index
    @query = query(:datasets)

    respond_to do |format|
      format.csv { render plain: @query.as_csv }
      format.tsv { render plain: @query.as_tsv }
      format.any(:js, :json) { render_json @query.as_json }
    end
  end

  def show
    @query = query(:dataset)

    respond_to do |format|
      format.csv { render plain: @query.as_csv }
      format.tsv { render plain: @query.as_tsv }
      format.zip { redirect_to @query.as_json[:result][:csv_dump] }
      format.any(:js, :json) { render_json @query.as_json }
    end
  end

  def cacheable?
    params[:action] == 'show' && (params[:id] == 'latest') ? false : true
  end
end

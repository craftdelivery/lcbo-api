module V1
  module QueryHelper
    class ProductFinder < Finder
      attr_accessor :product_id

      def initialize(request, params)
        super
        self.product_id = (params[:id] || params[:product_id])
      end

      def self.get(raw_id)
        return unless id = Product.normalize_isn(raw_id)

        if id > Product::MAX_LCBO_ID
          Product.where(upc: id).first
        else
          Product.where(id: id).first
        end
      end

      def as_args
        [product_id]
      end
    end
  end
end

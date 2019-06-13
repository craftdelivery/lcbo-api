class ImageCacher
  S3 = 'https://s3.ca-central-1.amazonaws.com/lcbo-api'

  MIMES = {
    jpeg: 'image/jpeg',
    jpg:  'image/jpeg',
    png:  'image/png'
  }

  EXT = {
    'image/jpeg' => 'jpg',
    'image/png'  => 'png'
  }

  TYPES = {
    image_url: 'full',
    image_thumb_url: 'thumb'
  }

  def self.run
    new.run
  end

  def initialize
    @s3 = Aws::S3::Client.new(
      region: 'ca-central-1',
      credentials: Aws::Credentials.new(
        Rails.application.secrets.s3_access_key,
        Rails.application.secrets.s3_secret_key
      )
    )
  end

  def uncached
    Product.where('image_url LIKE ?', '%www.lcbo.com%')
  end
  
  def all
    Product.all
  end
  def run
    imageTypes = [:image_url, :image_thumb_url]

    all.find_each do |product| 
      url = "https://www.lcbo.com/content/dam/lcbo/products/#{product.id}.jpg/jcr:content/renditions/cq5dam.web.1280.1280.jpeg"
      src_ext = File.extname(url).sub('.', '').downcase.to_sym
      src_mime = MIMES[src_ext]
      begin
        response = Excon.get(url)
        # unless response.status == 200
        #   puts url
        #   next
        # end
      rescue Excon::Error::Socket, Excon::Error::Timeout => e
        puts e
        next
      end

      puts "Saving product #{product.id}..."
      key = store_product_image(product, src_mime, response.body)
      product.update_column(:image_url, "https://#{S3}/#{key}")
    end
  end

  def store_product_image(product, mime, data)
    ext    = EXT[mime] || raise("FUCK")
    bucket = Rails.application.secrets.s3_bucket
    key    = "#{product.id}.#{ext}"

    @s3.put_object(
      acl: 'public-read',
      key: key,
      bucket: bucket,
      content_type: mime,
      body: data
    )

    key
  end
end
require 'webp_ffi'
require 'rest-client'

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
  def self.imgsize
    new.imgsize
  end
  def self.getsize(id)
    new.getsize(id)
  end
  def self.run
    new.run
  end
  def self.runnil
    new.runnil
  end
  def self.one(id)
    new.one(id)
  end
  def self.onewebp(id)
    new.onewebp(id)
  end
  def self.towebp(rev)
    new.towebp(rev)
  end
  def self.dels3nil
    new.dels3nil
  end
  def self.fix2https
    new.fix2https
  end
  def initialize
    @s3 = Aws::S3::Client.new(
      region: 'ca-central-1',
      credentials: Aws::Credentials.new(
        Rails.application.secrets.s3_access_key,
        Rails.application.secrets.s3_secret_key
      )
    )
    @s3Resource = Aws::S3::Resource.new(
      region: 'ca-central-1',
      credentials: Aws::Credentials.new(
        Rails.application.secrets.s3_access_key,
        Rails.application.secrets.s3_secret_key
      )
    )
  end

  # do not like /lcbo-api/
  def uncached
    Product.where('image_url LIKE ?', '%www.lcbo.com%')
  end
  
  def all
    Product.all
  end


  # fix double https
  def fix2https
    products = Product.where("image_url LIKE ?", "https://https%")
    if products.length == 0
      return
    end
    products.each do |product|
      new_url = product.image_url.sub("https://https", 'https')
      puts new_url
      product.update_column(:image_url, new_url)
    end
    count = Product.where("image_url LIKE ?", "https://https%").count
    puts "#{count} bad urls remaining"
  end

  # TODO set image_url to "" one at a time or by array

  def save_to_tempfile(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port) do |http|
      resp = http.get(uri.path)
      file = Tempfile.new('foo', Dir.tmpdir, 'wb+')
      file.binmode
      file.write(resp.body)
      file.flush
      file
    end
  end

  # TEMP :image_thumb_url set to 'webp'
  def towebp(rev)
    webp_mime = 'image/webp'
    # products = Product.where.not(:image_thumb_url => 'webp')
    prod_list = Product.where.not(:image_thumb_url => 'webp')
    # if rev == 'rev'
    #   prod_list = products.reverse_order.slice(0, products.length / 2)
    # else
    #   prod_list = products.slice(0, products.length / 2)
    # end
    puts prod_list.length
    prod_list.each do |product| 
      url = product.image_url
      id = product.id
      if url.nil? || url == ''
        next
      end
      begin
        if url.include? 'lcbo-api'
          inFile = File.join(Rails.root, "/tmp/jpg/#{id}.jpg")
          outFile = File.join(Rails.root, "/tmp/webp/#{id}.webp")
          file = File.open(inFile, 'wb' ) do |output|
            output.write RestClient.get(url)
          end
          webp = WebP.encode(inFile, outFile, quality: 25)
          if webp
            webp_file = File.open(outFile, 'rb')
            @s3.put_object(
              acl: 'public-read',
              key: "#{product.id}.webp",
              bucket: 'lcbo-api-webp',
              content_type: webp_mime,
              body: webp_file.read
            )
            webp_file.close
            product.update_column(:image_thumb_url, 'webp')
          else
            puts "webp encoding failed for #{id}"
          end
        else
          puts "not an s3 lcbo-api image: #{url}"  
        end
      rescue SocketError => e
         puts "Socket Error: #{e.message} #{url}" 
         next
      rescue Error => e
         puts e.message
         next
      end
    end
  end

  # https://github.com/le0pard/webp-ffi
  def onewebp(id)
    webp_mime = 'image/webp'
    product = Product.find(id)
    url = product.image_url
    if url.include? 'lcbo-api'
      inFile = File.join(Rails.root, "/tmp/jpg/#{id}.jpg")
      outFile = File.join(Rails.root, "/tmp/webp/#{id}.webp")
      file = File.open(inFile, 'wb' ) do |output|
        output.write RestClient.get(url)
      end
      webp = WebP.encode(inFile, outFile, quality: 25)
      if webp
        webp_file = File.open(outFile, 'rb')
        @s3.put_object(
          acl: 'public-read',
          key: "#{id}.webp",
          bucket: 'lcbo-api-webp',
          content_type: webp_mime,
          body: webp_file.read
        )
        webp_file.close
        product.update_column(:image_thumb_url, 'webp')
        puts "webp OK for #{id}"
      else
        puts "webp encoding failed for #{id}"
      end
    else
      puts "not an s3 lcbo-api image: #{url}"  
    end
  end

  def one(id)
    product = Product.find(id)
    url = "https://www.lcbo.com/content/dam/lcbo/products/#{id}.jpg/jcr:content/renditions/cq5dam.web.1280.1280.jpeg"
    src_ext = File.extname(url).sub('.', '').downcase.to_sym
    src_mime = MIMES[src_ext]
    begin
      response = Excon.get(url)
    rescue Excon::Error::Socket, Excon::Error::Timeout => e
      puts e
      return
    end
    puts response.to_yaml
    puts "#{response.body.length}"
    return
    key = store_product_image(id, src_mime, response.body)
    obj = @s3Resource.bucket(Rails.application.secrets.s3_bucket).object(key)
    if obj.exists?
      objUrl = "#{S3}/#{key}"
      puts "SAVED: #{objUrl}"
      product.update_column(:image_url, objUrl)
    else
      puts "ERROR saving #{key}"
      product.update_column(:image_url, "")
    end
  end
  
  def dels3nil
    zeros = []
    bucket = Rails.application.secrets.s3_bucket
    @s3.list_objects_v2(bucket: bucket).each do |resp|
      resp.contents.each do |obj|
        if obj.size == 0
          zeros.push(obj)
          # puts "#{obj.key} zero"
          del = @s3.delete_object(
            key: obj.key,
            bucket: bucket
          )
          puts "DEL #{obj.key}"
        end
      end
    end
    puts "Found #{zeros.length} zeros"
    # zeros.each do |obj|
    #   @s3.delete_object(
    #     key: key,
    #     bucket: bucket
    #   )
  end

  def getsize(id)
    bucket = Rails.application.secrets.s3_bucket
    key = "#{id}.jpg"
    obj = @s3.get_object(
      key: key,
      bucket: bucket
    )
    puts obj
    # obj = @s3Resource.bucket(Rails.application.secrets.s3_bucket).objects.find(key)
    # puts obj.to_yaml
    # puts "#{obj.key} #{obj.content_length}"
  end

  def prodFrom
    Product.where('id > ?', 39263).where.not(:image_url => nil)
  end
  # first remove url from 0 len images
  # then run sepurgezero script
  # then fix run so it checks for content length (copy from here)
  # then make note of fails to try again later
  def imgsize
    notFound = []
    bucket = Rails.application.secrets.s3_bucket
    puts prodFrom.count
    prodFrom.each do |product|
      key = "#{product.id}.jpg"
      begin
        obj = @s3.get_object(
          key: key,
          bucket: bucket,
        )
      rescue Aws::S3::Errors::NoSuchKey => e
        puts "#{key} nil len"
        product.update_column(:image_url, nil)
        notFound.push(key)
        next
      end
      if obj.content_length == 0
        puts "#{key} not found"
        product.update_column(:image_url, nil)
      end
    end
    if notFound.length > 0
      puts 'NOT FOUND:'
      puts notFound
    end
  end

  def header(id)
    product = Product.find(id)
  end

  # todo call onewebp(id)
  def runnil
    bucket = Rails.application.secrets.s3_bucket
    notFound = []
    errorSaving = []
    imageTypes = [:image_url]
    Product.where(:image_url => nil).each do |product| 
      url = "https://www.lcbo.com/content/dam/lcbo/products/#{product.id}.jpg/jcr:content/renditions/cq5dam.web.1280.1280.jpeg"
      src_ext = File.extname(url).sub('.', '').downcase.to_sym
      src_mime = MIMES[src_ext]
      begin
        response = Excon.get(url)
      rescue Excon::Error::Socket, Excon::Error::Timeout => e
        puts e
        next
      end
      puts response.to_yaml
      next
      if response.body.length > 0
        key = store_product_image(product.id, src_mime, response.body)
        objUrl = "#{S3}/#{key}"
        puts "SAVED: #{objUrl}"
        product.update_column(:image_url, objUrl)
      else
        puts "ERROR saving #{key}"
        product.update_column(:image_url, nil)
        errorSaving.push(key)
      end
    end
    puts 'NOT FOUND:'
    puts notFound
    puts '-' * 80
    puts 'ERROR SAVING:'
    puts errorSaving
  end

  # TODO do in small batches
  # check nil urls and try again
  def run
    puts 'NOT RUN::: FIX BLANK SIZE IMAGES FIRST'
    return
    bucket = Rails.application.secrets.s3_bucket
    notFound = []
    errorSaving = []
    imageTypes = [:image_url, :image_thumb_url]
    all.find_each do |product| 
      url = "https://www.lcbo.com/content/dam/lcbo/products/#{product.id}.jpg/jcr:content/renditions/cq5dam.web.1280.1280.jpeg"
      src_ext = File.extname(url).sub('.', '').downcase.to_sym
      src_mime = MIMES[src_ext]
      begin
        response = Excon.get(url)
      rescue Excon::Error::Socket, Excon::Error::Timeout => e
        puts e
        next
      end
      if response.body.length > 0
        key = store_product_image(product.id, src_mime, response.body)
      else
        puts "NO CONTENT LENGTH FOR #{key}"
      end
      begin
        obj = @s3.get_object(
          key: key,
          bucket: bucket,
        )
      rescue Aws::S3::Errors::NoSuchKey => e
        notFound.push(key)
        next
      end

      if obj.content_length > 0
        objUrl = "#{S3}/#{key}"
        puts "SAVED: #{objUrl}"
        product.update_column(:image_url, objUrl)
      else
        puts "ERROR saving #{key} NO_CONTENT"
        errorSaving.push(key)
      end
    end
    puts 'NOT FOUND:'
    puts notFound
    puts '-' * 80
    puts 'ERROR SAVING:'
    puts errorSaving
  end

  def store_product_image(id, mime, data)
    ext    = EXT[mime] || raise("FUCK")
    bucket = Rails.application.secrets.s3_bucket
    key    = "#{id}.#{ext}"

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
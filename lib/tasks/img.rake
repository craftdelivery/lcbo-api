desc 'Cache Images'
task img: :environment do
  ImageCacher.run
end
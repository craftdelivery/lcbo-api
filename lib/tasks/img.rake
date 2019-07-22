desc 'Cache Images'
task :img => :environment do
  ImageCacher.run
end
task :imgnil=> :environment do
  ImageCacher.runnil
end
task :oneimg, [:id] => :environment do |task, args|
  ImageCacher.one(args.id)
end

task :onewebp, [:id] => :environment do |task, args|
  ImageCacher.onewebp(args.id)
end

task :towebp, [:rev] => :environment do |task, args|
  ImageCacher.towebp(args.rev)
end

task :imgsize => :environment do
  ImageCacher.imgsize
end

task :getsize, [:id] => :environment do |task, args|
  ImageCacher.getsize(args.id)
end

task :dels3nil => :environment do
  ImageCacher.dels3nil
end

task :fix2https => :environment do
  ImageCacher.fix2https
end
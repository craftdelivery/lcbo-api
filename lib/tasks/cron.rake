desc 'Run scheduled tasks'
task cron: :environment do
  Crawl.where(state: [:init, :running, :paused]).destroy_all
  Crawler.run
end

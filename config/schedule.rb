set :output, '/home/lcboapi/logs/cron.log'

job_type :rake, 'cd :path && RAILS_ENV=:environment bundle exec rake :task :output'

every 1.day, at: '1:05 AM' do
  rake 'cron'
end

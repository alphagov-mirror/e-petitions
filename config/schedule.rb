# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

env :PATH, ENV['PATH']

every :day, at: '1.45am' do
  rake "epets:constituencies:fetch", output: nil
end

every :day, at: '2.30am' do
  rake "epets:petitions:count", output: nil
end

every :day, at: '3.30am' do
	rake "epets:petitions:update_statistics", output: nil
end

every :day, at: '7.00am' do
  rake "epets:petitions:close", output: nil
end

every :day, at: '7.15am' do
  rake "epets:petitions:debated", output: nil
end

every :day, at: '7.30am' do
  rake "epets:petitions:extend_deadline", output: nil
end

every 15.minutes do
  rake "epets:site:signature_counts", output: nil
end

every :hour, at: 15 do
  rake "epets:site:trending_ips", output: nil
end

every :hour, at: 10 do
  rake "epets:site:trending_domains", output: nil
end

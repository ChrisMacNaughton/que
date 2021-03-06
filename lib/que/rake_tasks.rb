namespace :que do
  desc "Process Que's jobs using a worker pool"
  task :work => :environment do
    require 'logger'

    Que.logger       = Logger.new(STDOUT)
    Que.worker_count = (ENV['WORKER_COUNT'] || 4).to_i

    stop = false
    trap('INT'){stop = true}

    loop do
      sleep 0.01
      break if stop
    end
  end

  desc "Create Que's job table"
  task :create => :environment do
    Que.create!
  end

  desc "Drop Que's job table"
  task :drop => :environment do
    Que.drop!
  end

  desc "Clear Que's job table"
  task :clear => :environment do
    Que.clear!
  end
end

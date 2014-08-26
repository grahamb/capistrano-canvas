namespace :canvas do 

  desc "Create tmp directory"
  task :create_tmp do
    on roles(:all) do
      execute :mkdir, '-p', "#{release_path}/tmp"
    end
  end

  desc "Set application nodes from config file"
  task :set_app_nodes do
    on primary :db do
      stage = fetch :stage
      prefix = fetch :app_node_prefix
      nodes = capture "/usr/local/canvas/bin/getappnodes #{stage}"
      range = *(1..nodes.to_i)
      roles[:app].clear
      range.each do |node|
        parent.role :app, "#{prefix}#{node}.tier2.sfu.ca"
      end
    end
  end

  desc "Create symlink for files folder to mount point"
  task :symlink_canvasfiles do
    on roles(:all) do
      execute "mkdir -p #{release_path}/mnt/data && ln -s /mnt/data/canvasfiles #{release_path}/mnt/data/canvasfiles"
    end
  end

  desc "Copy config files from /mnt/data/canvasconfig/config"
  task :copy_config do
    puts "original"
    on roles(:all) do
      execute "sudo CANVASDIR=#{release_path} /etc/init.d/canvasconfig start"
    end
  end

  desc "Clone QTIMigrationTool"
  task :clone_qtimigrationtool do
    on roles(:all) do
      within release_path do
        execute :git, 'clone', 'https://github.com/instructure/QTIMigrationTool.git', 'QTIMigrationTool'
      end
    end
  end

  desc "Install node dependencies"
  task :npm_install do
    on roles(:all) do
      within release_path do
        execute :npm, 'install', '--silent'
      end
    end
  end

  desc "Compile static assets"
  task :compile_assets => :npm_install do
    on roles(:all) do
      within release_path do
        execute :rake, 'canvas:compile_assets[false]'
        execute :chown, '-R', 'canvasuser:canvasuser', '.'
      end
    end
  end

  desc "Run predeploy db migration task"
  task :migrate_predeploy do
    on primary :db do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:migrate:predeploy"
        end
      end
    end
  end

  desc "Load new notification types"
  task :load_notifications do
    on primary :db do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:load_notifications'
        end
      end
    end
  end

  desc "Log the deploy to graphite"
  task :log_deploy do
    ts = Time.now.to_i
    cmd = "echo 'stats.canvas.#{stage}.deploys 1 #{ts}' | nc #{stats_server} 2003"
    run_locally do
      execute cmd
    end
  end

  desc "Ping the canvas server to actually restart the app"
  task :ping do
    run_locally do
      execute "curl -m 10 --silent #{fetch(:canvas_url)}/sfu/api/v1/terms/current"
    end
  end

  namespace :delayed_jobs do
    %w[start stop restart].each do |command|
      desc "#{command} the delayed_jobs processor"
      task command do
        on roles(:db) do
          execute "sudo /etc/init.d/canvas_init #{command}"
        end
      end
    end
  end

  namespace :meta_tasks do

    desc "Tasks that need to run before _started_"
    task :before_started do
      invoke 'canvas:delayed_jobs:stop'
    end

    desc "Tasks that need to run before _updated_"
    task :before_updated do
      invoke 'canvas:copy_config'
      invoke 'canvas:clone_qtimigrationtool'
      invoke 'canvas:symlink_canvasfiles'
      invoke 'canvas:migrate_predeploy'
    end

    desc "Tasks that run after _updated_"
    task :after_updated do
      invoke 'canvas:compile_assets'
      invoke 'canvas:load_notifications'
    end

    desc "Tasks that run after _published_"
    task :after_published do
      invoke 'canvas:create_tmp'
      invoke 'deploy:restart'
      invoke 'canvas:delayed_jobs:start'
      invoke 'canvas:log_deploy'
    end

  end

end
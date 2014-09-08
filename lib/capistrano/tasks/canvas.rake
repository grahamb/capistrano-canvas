namespace :canvas do 

  desc "Create tmp directory"
  task :create_tmp do
    on roles(:all) do
      execute :mkdir, '-p', "#{release_path}/tmp"
    end
  end

  desc "Clone QTIMigrationTool"
  task :clone_qtimigrationtool do
    on roles(:all) do
      within release_path do
        execute :git, 'clone', 'https://github.com/instructure/QTIMigrationTool.git', 'vendor/QTIMigrationTool'
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

  # TODO: make the chown user a config setting
  desc "Compile static assets"
  task :compile_assets => :npm_install do
    on roles(:all) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          user = fetch(:user)
          execute :rake, 'canvas:compile_assets[false]'
          execute :chown, '-R', "#{user}:#{user}", '.'
        end
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

  # TODO: create a separate job-processor role for this task
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
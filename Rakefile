require 'yaml'
require_relative './lib/magma'

namespace :db do
  desc "Run migrations"
  task :migrate, [:version] do |t, args|
    Sequel.extension :migration

    Magma.instance.configure(
      YAML.load(File.read("config.yml"))
    )
    Magma.instance.connect(Magma.instance.config :db)
    db = Magma.instance.db

    Magma.instance.config(:project_path).split(/\s+/).each do |project_dir|
      table = "schema_info_#{project_dir.gsub(/[^\w]+/,'_').sub(/^_/,'').sub(/_$/,'')}"
      if args[:version]
        puts "Migrating to version #{args[:version]}"
        Sequel::Migrator.run(db, File.join(project_dir, 'migrations'), table: table, target: args[:version].to_i)
      else
        puts "Migrating to latest"
        Sequel::Migrator.run(db, File.join(project_dir, 'migrations'), table: table)
      end
    end
  end
end

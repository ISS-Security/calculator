require './app'
require 'sinatra/activerecord/rake'   # gives us db:migrate task

require 'rake/testtask'               # gives us Rake::TestTask
require 'config_env/rake_tasks'       # gives us config_env:heroku task

desc "Run all tests"
Rake::TestTask.new(name=:spec) do |t|
  t.pattern = 'spec/*_spec.rb'
end

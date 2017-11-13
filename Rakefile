require 'bundler/gem_tasks'
require 'appraisal'
require 'rake/testtask'
require 'rspec/core/rake_task'
require 'cucumber/rake/task'

desc 'Default: clean, all.'
task :default => [:clean, :all]

desc 'Test the activerecord-tableless on all supported Rails versions.'
task :all do |t|
  # TODO: cucumber feature specs appear to be written for Rails 2, and will need an overhaul for Rails 5.
  if ENV['BUNDLE_GEMFILE']
    exec('rake test spec')
    # exec('rake test spec cucumber')
  else
    Rake::Task["appraisal:install"].execute
    exec('rake appraisal test spec')
    # exec('rake appraisal test spec cucumber')
  end
end

desc 'Test the activerecord-tableless plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  # Put spec opts in a file named .rspec in root
end

desc 'Run integration test'
Cucumber::Rake::Task.new do |t|
  t.cucumber_opts = %w{--format progress}
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "tmp"
  FileUtils.rm_rf "pkg"
  FileUtils.rm_rf "public"
  Dir.glob("activerecord-tableless-*.gem").each{|f| FileUtils.rm f }
end

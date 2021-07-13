# frozen_string_literal: true

source "https://rubygems.org"

gem 'activesupport', '~> 5.2.0'
# chef-api is deprecated but brings in fewer dependencies
# than the official chef gem
gem 'chef-api', '~> 0.10'
gem 'colorize'
gem 'gitlab', '~> 4.17'
gem 'http', '~> 4.3.0'
gem 'parallel', '~> 1.14'
gem 'rake'
gem 'retriable', '~> 3.1'
gem 'rugged', '~> 1.1'
gem 'semantic_logger', '~> 4.6.1'
gem 'sentry-raven', '~> 3.0', require: false
gem 'slack-ruby-block-kit', '~> 0.14.0'
gem 'unleash', '~> 0.1.5'
gem 'version_sorter', '~> 2.2.0'

group :metrics do
  gem 'prometheus-client', '~> 2.1.0'
end

group :development, :test do
  gem 'byebug'
  gem 'climate_control', '~> 0.2.0'
  gem 'fuubar', require: false
  gem 'pry'
  gem 'rspec', '~> 3.8'
  gem 'rubocop', '~> 1.6.0'
  gem 'rubocop-performance', '~> 1.9.0'
  gem 'rubocop-rspec', '~> 2.0.0'
  gem 'simplecov', '~> 0.16.0'
  gem 'timecop', '~> 0.9.0'
  gem 'vcr', '~> 5.0.0'
  gem 'webmock', '~> 3.8.0'
end

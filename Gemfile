# frozen_string_literal: true

source "https://rubygems.org"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~>6" # , '5.2.0' #, '>= 5.0.0.rc1', '< 5.1'
# Use sqlite3 as the database for Active Record
# gem 'sqlite3'
# Use Puma as the app server
# gem 'webrick'
# gem "markdown-rails"
gem "puma" # , '~> 3.0'
# Use SCSS for stylesheets
gem "sass-rails" # , '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem "uglifier" # , '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
# gem "coffee-rails" # , '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem "therubyracer", platforms: :ruby

# Use jquery as the JavaScript library
# gem "jquery-rails"
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem "turbolinks" # , '5.1.1' #, '~> 5.x'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder" # , '~> 2.0'
gem "cancancan"
gem "bootsnap"
gem "lockbox"


group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "capybara"
  gem "byebug", platform: :mri
  gem "foreman"
end

##############################
## MURBs defaults
##############################

##
## BASIC
##
gem "bundler-audit"
gem "pg" #, "~>0.21"
gem "devise", git: "https://github.com/heartcombo/devise.git"
# gem 'omniauth-facebook'
# gem 'omniauth-google-oauth2'
gem "carrierwave" # , '~> 1.0'
gem "carrierwave-imageoptimizer"
gem "mini_magick" # transforming images
gem "nokogiri"
gem "attribute_normalizer" # keeps the database clean
##
## SEARCH
##

gem "elasticsearch-model", "~> 7"
gem "elasticsearch-rails", "~> 7"
gem "rspec-rails", group: [:development, :test]

##
## DEVELOPMENT
##
group :development do
  gem "letter_opener"
  gem "capistrano"
  gem "capistrano-rbenv"
  gem "capistrano-bundler"
  gem "capistrano-rails"
  gem "highline"
  gem "web-console" # , '~> 2.0'
  gem "listen" # , '~> 3.0.5'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # gem 'spring'
  # gem 'spring-watcher-listen' #, '~> 2.0.0'
end

##
## INTERACTIVITY
##

gem "simple_form"
gem "kramdown"

##
## STYLING
##

gem "foundation-rails", "~> 6.3.0"

##
## OTHER FREQUENTLY USED
##

gem "acts-as-taggable-on"
gem "act_as_time_as_boolean"
gem "workbook", git: "https://github.com/murb/workbook.git"
gem "nested_form"
gem "paper_trail"
gem "paper_trail-association_tracking"
gem "keyword_finder"
gem "daemons"
gem "redis-rails" #jobs
gem "dalli" #memcache
gem "exception_notification"
gem "zipline"
gem "rack-headers_filter"
gem "strip_attributes"
gem 'omniauth'
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

gem "sidekiq", "~> 5.0"
gem "sidekiq-scheduler"
gem "sidekiq-unique-jobs"

gem "webpacker"

gem "rack-mini-profiler"
gem "flamegraph"
gem "stackprof"
gem "memory_profiler"

group :test do
  gem "database_cleaner"
  gem "simplecov", require: false
  gem "bullet"
end
gem "standard", group: [:development, :test]
gem 'dotenv-rails', groups: [:development, :test]
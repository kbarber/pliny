# make sure this is set before Sinatra is required
ENV["RACK_ENV"] = "test"

require "bundler"
Bundler.require

require "rack/test"
require "sinatra/namespace"
require "sinatra/router"
require "timecop"

require_relative "../lib/pliny"
Pliny::Utils.require_glob("./spec/support/**/*.rb")

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.expect_with :minitest
  config.mock_with :rr
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.before :each do
    Pliny::RequestStore.clear!
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # the rack app to be tested with rack-test:
  def app
    @rack_app || fail("Missing @rack_app")
  end
end

Pliny.stdout = StringIO.new
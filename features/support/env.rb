require 'dotenv'
Dotenv.load

require 'capybara/rspec'
require 'capybara/cucumber'
require 'cucumber/rspec/doubles'

require_relative 'custom_config'
include CustomConfig

require 'i18n'
I18n.load_path += Dir.glob('config/locales/*.yml')

require 'active_support/all'
Time.zone = ENV['TIMEZONE'] || 'Pacific Time (US & Canada)'

require_relative 'utils'

is_parallel_primary = parallel_test_number == 1
is_parallel_secondary = !is_parallel_primary && parallel_test_number.present?
is_parallel = is_parallel_primary || is_parallel_secondary

custom_host = ENV['APP_HOST'] || env_config['app_host']

if is_parallel_secondary && !custom_host
  timeout_at = Time.now + 60.seconds
  while !File.exists?('cucumber-primary-ready')
    if Time.now > timeout_at
      raise "Cucumber runner #{parallel_test_number} timed out waiting for the primary runner to start!"
    end
    sleep(1)
  end
end

if !custom_host
  ENV['FHLB_INTERNAL_IPS'] = '0.0.0.0/0 0::0/0' # all IPs are internal
  ENV['RAILS_ENV'] ||= 'test' # for some reason we default to development in some cases
  ENV['RACK_ENV'] ||= 'test'
  ENV['REDIS_URL'] ||= 'redis://localhost:6379/'

  require_relative '../../lib/redis_helper'
  resque_namespace = ['resque', ENV['RAILS_ENV'], 'cucumber', parallel_test_number, Process.pid].compact.join('-')
  ENV['RESQUE_REDIS_URL'] ||= RedisHelper.add_url_namespace(ENV['REDIS_URL'], resque_namespace)
  flipper_namespace = ['flipper', ENV['RAILS_ENV'], 'cucumber', parallel_test_number, Process.pid].compact.join('-')
  ENV['FLIPPER_REDIS_URL'] ||= RedisHelper.add_url_namespace(ENV['REDIS_URL'], flipper_namespace)
  cache_namespace = ['cache', ENV['RAILS_ENV'], 'cucumber', parallel_test_number, Process.pid].compact.join('-')
  ENV['CACHE_REDIS_URL'] ||= RedisHelper.add_url_namespace(ENV['REDIS_URL'], cache_namespace)

  puts "Flipper initialized (#{ENV['FLIPPER_REDIS_URL']})"

  require 'open3'
  require ::File.expand_path('../../../config/environment',  __FILE__)
  require 'capybara/rails'
  require 'net/ping/tcp'

  WebMock.allow_net_connect! # allow all Net connections

  AfterConfiguration do
    DatabaseCleaner.clean_with :truncation if !is_parallel || is_parallel_primary
  end

  class ServiceLaunchError < RuntimeError
  end

  def port_retry
    tries ||= 3
    port = find_available_port
    yield port
  rescue ServiceLaunchError => e
    tries = tries - 1
    if tries <= 0
      raise e
    else
      puts "#{e.message}.. retrying.."
      retry
    end
  end

  def find_available_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1]
  ensure
    server.close if server
  end

  def check_service(port, thr, out, err, name=nil, host='127.0.0.1')
    name ||= "#{host}:#{port}"
    pinger = Net::Ping::TCP.new host, port, 1
    now = Time.now
    while !pinger.ping
      if Time.now - now > 10
        if ENV['VERBOSE']
          out.autoclose = false
          err.autoclose = false
          Process.kill('INT', thr.pid) rescue Errno::ESRCH
          thr.value
          IO.copy_stream(out, STDOUT)
          IO.copy_stream(err, STDERR)
        end
        out.close
        err.close
        raise ServiceLaunchError.new("#{name} failed to start")
      end
      sleep(1)
    end
  end

  port_retry do |ldap_port|
    ldap_root = Rails.root.join('tmp', "openldap-data-#{Process.pid}")
    ldap_server = File.expand_path('../../../ldap/run-server',  __FILE__) + " --port #{ldap_port} --root-dir #{ldap_root}"
    if ENV['VERBOSE']
      ldap_server += ' --verbose'
    end
    puts "LDAP starting, ldap://localhost:#{ldap_port}"
    ldap_stdin, ldap_stdout, ldap_stderr, ldap_thr = Open3.popen3(ldap_server)
    at_exit do
      kill_background_process(ldap_thr, ldap_stdin)
      FileUtils.rm_rf(ldap_root)
    end
    check_service(ldap_port, ldap_thr, ldap_stdout, ldap_stderr, 'LDAP')
    # we close the LDAP server's STDIN and STDOUT immediately to avoid a ruby buffer depth issue.
    ldap_stdout.close
    ldap_stderr.close
    puts 'LDAP Started.'

    puts `#{ldap_server} --reseed`
    ENV['LDAP_PORT'] = ldap_port.to_s
    ENV['LDAP_EXTRANET_PORT'] = ldap_port.to_s
  end


  port_retry do |mapi_port|
    puts "Starting MAPI: http://localhost:#{mapi_port}"
    mapi_server = "rackup --port #{mapi_port} #{File.expand_path('../../../api/config.ru', __FILE__)}"
    mapi_stdin, mapi_stdout, mapi_stderr, mapi_thr = Open3.popen3({'RACK_ENV' => 'test'}, mapi_server)

    at_exit do
      kill_background_process(mapi_thr, mapi_stdin)
    end
    check_service(mapi_port, mapi_thr, mapi_stdout, mapi_stderr, 'MAPI')

    # we close the MAPI server's STDIN and STDOUT immediately to avoid a ruby buffer depth issue.
    mapi_stdout.close
    mapi_stderr.close
    puts 'MAPI Started.'
    ENV['MAPI_ENDPOINT'] = "http://localhost:#{mapi_port}/mapi"
  end

  verbose = ENV['VERBOSE'] # Need to remove the VERBOSE env variable due to a conflict with Resque::VerboseFormatter and ActiveJob logging
  begin
    ENV.delete('VERBOSE')
    puts "Starting resque-pool (#{ENV['RESQUE_REDIS_URL']})..."
    resque_pool = "resque-pool -i -E #{ENV['RAILS_ENV'] || ENV['RACK_ENV']}"
    resque_stdin, resque_stdout, resque_stderr, resque_thr = Open3.popen3({'TERM_CHILD' => '1'}, resque_pool)
  ensure
    ENV['VERBOSE'] = verbose # reset the VERBOSE env variable after resque process is finished.
  end

  at_exit do
    kill_background_process(resque_thr, resque_stdin, 'TERM')
  end

  resque_time_out_at = Time.now + 20.seconds

  while Time.now < resque_time_out_at && Resque.workers.count == 0
    Resque.workers.each do |worker|
      worker.prune_dead_workers # helps ensure we have an accurate count
    end
    sleep 1
  end

  unless Resque.workers.count > 0
    kill_background_process(resque_thr, resque_stdin, 'TERM')
    IO.copy_stream(resque_stdout, STDOUT)
    IO.copy_stream(resque_stderr, STDERR)
    raise 'resque-pool failed to start'
  end

  # we close the resque-pool's STDIN and STDOUT immediately to avoid a ruby buffer depth issue.
  resque_stdout.close
  resque_stderr.close
  puts 'resque-pool Started.'


else
  Capybara.app_host = custom_host
end

puts "Capybara.app_host: #{Capybara.app_host}"

at_exit do
  puts "App Health Check Results: "
  STDOUT.flush
  puts %x[curl -m 10 -sL #{Capybara.app_host}/healthy]
  puts "Finished run `#{run_name}`"
end

AfterConfiguration do
  if Capybara.app_host.nil?
    Capybara.app_host = "#{Capybara.app_host || ('http://' + Capybara.current_session.server.host)}:#{Capybara.server_port || (Capybara.current_session.server ? Capybara.current_session.server.port : false) || 80}"
  end
  Rails.configuration.mapi.endpoint = ENV['MAPI_ENDPOINT'] unless custom_host
  url = Capybara.app_host
  puts url
  result = nil
  10.times do |i|
    result = %x[curl -w "%{http_code}" -m 3 -sL #{url} -o /dev/null]
    if result == '200'
      break
    end
    wait_time = ENV['WAIT_TIME'] ? ENV['WAIT_TIME'].to_i : 3
    puts "App not serving heartbeat (#{url})... waiting #{wait_time}s (#{i + 1} tr"+(i==0 ? "y" : "ies")+")"
    sleep wait_time
  end
  raise Capybara::CapybaraError.new('Server failed to serve heartbeat') unless result == '200'
  sleep 10 #sleep 10 more seconds after we get our first 200 response to let the app come up more
  if !is_parallel || is_parallel_primary
    require Rails.root.join('db', 'seeds.rb') unless custom_host
  end

  if is_parallel_primary
    FileUtils.touch('cucumber-primary-ready')
    at_exit do
      FileUtils.rm_rf('cucumber-primary-ready')
    end
    sleep(30) # primary runner needs to sleep to make sure secondary workers see the sentinel (in the case where the primary work exits quickly... ie no work to do)
  end

  sleep(parallel_test_number.to_i) # stagger runners to avoid certain race conditions

  puts "Starting run `#{run_name}`"
end

AfterStep('@pause') do
  print 'Press Return to continue'
  STDIN.getc
end

if ENV['CUCUMBER_INCLUDE_SAUCE_SESSION']
  Around do |scenario, block|
    JenkinsSauce.output_jenkins_log(scenario)
    block.call
    ::Capybara.current_session.driver.quit if ENV['CUCUMBER_INCLUDE_SAUCE_SESSION'] == 'scenario'
  end
end

Around do |scenario, block|
  begin
    block.call
  ensure
    Timecop.return if defined?(Timecop)
  end
end

Around do |scenario, block|
  features = {}
  feature_state = {}
  scenario.source_tag_names.each do |tag|
    matches = tag.match(/\A@flip-(on|off)-(.+)\z/)
    if matches
      features[matches[2]] = (matches[1] == 'on')
    end
  end
  unless custom_host
    features.each do |feature_name, enable|
      feature = Rails.application.flipper[feature_name]
      feature_state[feature] = {
          groups: feature.groups_value,
          boolean: feature.boolean_value,
          actors: feature.actors_value,
          percentage_of_actors: feature.percentage_of_actors_value,
          percentage_of_time: feature.percentage_of_time_value
        }
    end
    features.each do |feature_name, enable|
      feature = Rails.application.flipper[feature_name]
      enable ? feature.enable : feature.disable
    end
  end
  begin
    if custom_host && features.present? # we can't mutate custom hosts, so skip the scenario
      skip_this_scenario
    else
      block.call
    end
  ensure
    feature_state.each do |feature, state|
      state[:boolean] ? feature.enable : feature.disable
      feature.enable_percentage_of_time(state[:percentage_of_time])
      feature.enable_percentage_of_actors(state[:percentage_of_actors])
      state[:groups].each do |group|
        feature.enable_group(group)
      end
      state[:actors].each do |actor|
        feature.enable_group(actor)
      end
    end
  end
end

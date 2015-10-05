require "norikra/helper/version"
require "thor"
require "norikra/client"
require "norikra/client/cli"
require "net/http"
require "json"

module Norikra

  class Target < Thor
    include Norikra::Client::CLIUtil
    desc "see TARGET", "see event stream of TARGET"
    option :format, :type => :string, :default => 'json', :desc => "format of output data per line of stdout [json(default), ltsv]"
    option :time_key, :type => :string, :default => 'time', :desc => "output key name for event time (default: time)"
    option :time_format, :type => :string, :default => '%Y/%m/%d %H:%M:%S', :desc => "output time format (default: '2013/05/14 17:57:59')"
    @query_group = "norikra-helper"
    
    def see(target)
      formatter = formatter(options[:format])
      time_formatter = lambda{|t| Time.at(t).strftime(options[:time_format])}
      
      begin
        res = Net::HTTP.get(options[:host],"/json/target/#{target}",options[:http_port])
        if res == ""
          puts "No such target"
          exit 1
        end
        target_info = JSON.parse(res)
        puts target_info.to_s
        if target_info['fields'].size == 0
          puts "No fields registered"
          exit 1
        end
        query = %(SELECT #{target_info['fields'].map{  |i| "nullable(#{i['name']})" }.join(',')} FROM #{target_info['name']})
        query_name = "select_all_#{target_info['name']}"
        client(parent_options).register(query_name,@query_group, query)
        while true 
          client(parent_options).event(query_name).each do |time,event|
            event = {options[:time_key] => Time.at(time).strftime(options[:time_format])}.merge(event)
            puts formatter.format(event)
          end
          sleep 1
        end
      ensure
        client(parent_options).deregister(query_name)
      end
    end
  end

  class Query < Thor
    include Norikra::Client::CLIUtil
    desc "test QUERY", "test QUERY. Register temporary query"
    option :format, :type => :string, :default => 'json', :desc => "format of output data per line of stdout [json(default), ltsv]"
    option :time_key, :type => :string, :default => 'time', :desc => "output key name for event time (default: time)"
    option :time_format, :type => :string, :default => '%Y/%m/%d %H:%M:%S', :desc => "output time format (default: '2013/05/14 17:57:59')"
    option :query_file, :type => :string, :default => nil, :desc => "read query from file", :aliases => :f
    
    def test(query=nil)
      @query_name_prefix = "norikra-tmp-"
      @query_group = "norikra-helper"

      if query && options[:query_file]
        puts "Both query string and --query_file were specified"
        exit 1
      elsif not (query || options[:query_file])
        puts "Please specify query string or file."
        exit 1
      elsif options[:query_file]
        query = File.open(options[:query_file]).read
      end

      
      formatter = formatter(options[:format])
      time_formatter = lambda{|t| Time.at(t).strftime(options[:time_format])}

      query_name = @query_name_prefix + "#{$$}_#{Time.now.to_i}"
      client(parent_options).register(query_name, @query_group, query)
      puts "Registered query: #{query_name}"
      begin
        while true
          client(parent_options).event(query_name).each do |time,event|
            event = {options[:time_key] => Time.at(time).strftime(options[:time_format])}.merge(event)
            puts formatter.format(event)
          end
          sleep 1
        end
      ensure
        client(parent_options).deregister(query_name)
      end
    end
  end
  
  class HelperCLI < Thor
    include Norikra::Client::CLIUtil

    class_option :host, :type => :string, :default => 'localhost'
    class_option :port, :type => :numeric, :default => 26571
    class_option :http_port, :type => :numeric, :default => 26578
    
    desc "target CMD ...ARGS", "use targets"
    subcommand "target", Target
    desc "query CMD ...ARGS", "use query"
    subcommand "query", Query
  end
end

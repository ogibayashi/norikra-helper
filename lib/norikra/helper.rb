require "thor"
require "net/http"
require "json"
require "norikra/client/cli"
require "norikra/client"
require "norikra/log_reader"

module Norikra::Helper
  QUERY_NAME_PREFIX = "norikra-tmp-"
  QUERY_GROUP = "norikra-helper"

  class Query < Norikra::Client::Query

    desc "test QUERY", "test QUERY. Register temporary query and periodically fetch result"
    option :query_file, :type => :string, :default => nil, :desc => "read query from file", :aliases => :f
    option :format, :type => :string, :default => 'json', :desc => "format of output data per line of stdout [json(default), ltsv]"
    option :time_key, :type => :string, :default => 'time', :desc => "output key name for event time (default: time)"
    option :time_format, :type => :string, :default => '%Y/%m/%d %H:%M:%S', :desc => "output time format (default: '2013/05/14 17:57:59')"
    def test(query=nil)

      if query && options[:query_file]
        puts "Both query string and --query_file were specified"
        exit 1
      elsif not (query || options[:query_file])
        puts "Please specify query string or file."
        exit 1
      elsif options[:query_file]
        query = File.open(options[:query_file]).read
      end

      query_name = QUERY_NAME_PREFIX + "#{$$}_#{Time.now.to_i}"
      client(parent_options).register(query_name, QUERY_GROUP, query)
      STDERR.puts "Registered query: #{query_name}"
      begin
        while true
          x = Norikra::Client::Event.new([],options)
          x.parent_options = parent_options
          x.fetch(query_name)
          sleep 1
        end
      rescue Interrupt # Normal end
      ensure
        client(parent_options).deregister(query_name)
      end
    end

    desc "replace QUERY", "replace NAME QUERY. Replace the expression of query NAME to new one"
    option :query_file, :type => :string, :default => nil, :desc => "read query from file", :aliases => :f
    def replace(name, query=nil)

      if query && options[:query_file]
        puts "Both query string and --query_file were specified"
        exit 1
      elsif not (query || options[:query_file])
        puts "Please specify query string or file."
        exit 1
      elsif options[:query_file]
        query = File.open(options[:query_file]).read
      end

      current_query = client(parent_options).queries.select{  |q| q['name'] == name}.first
      unless current_query
        puts "Query with name: #{name} does not exist"
        exit 1
      end

      # try registering new query with temporary name for syntax check
      begin
        tmp_query_name = QUERY_NAME_PREFIX + "#{$$}_#{Time.now.to_i}"
        client(parent_options).register(tmp_query_name, QUERY_GROUP, query)
      rescue => e
        puts "Error in temporarily registering query. #{$!}"
        exit 1
      ensure
        wrap do 
          if client(parent_options).queries.select{  |q| q['name'] == tmp_query_name}.first
            client(parent_options).deregister(tmp_query_name)
          end
        end
      end

      # Actually de-regsister and register new query
      puts "Replacing query <#{name}>, old_expression: #{current_query['expression']}, new_expression: #{query}"
      wrap do 
        client(parent_options).deregister(name)
        client(parent_options).register(name, current_query['group'], query)
      end
    end

    desc "cleanup", "Remove queries created by norikra-helper and older than XX minutes."
    option :remove, :type => :boolean, :default => false, :desc => "Actually remove queries", :aliases => :r
    option :older_than, :type => :numeric, :default => 30, :desc => "Queries older than this time period (by minutes) will be removed. ", :aliases => :m
    def cleanup
      threshold = (Time.now - options[:older_than] * 60).to_i
      to_remove = client(parent_options).queries.select{  |q|
        q['group'] == QUERY_GROUP &&
          /#{QUERY_NAME_PREFIX}\d+_(\d+)$/ =~ q['name'] &&
        $1.to_i < threshold
      }
      to_remove.each{  |q|
        puts "#{q['name']} to be removed"
        if options[:remove]
          wrap do
            client(parent_options).deregister(q['name'])
          end
          puts "Removed #{q['name']}"
        end
      }
      
    end
    
  end

  class Event < Norikra::Client::Event

    desc "replay TARGET FILE", "Send saved events in FILE to TARGET"
    option :batch_size, :type => :numeric, :default => 10000, :desc => "records sent in once transferring (default: 10000)"
    def replay(target, file)
      client = client(parent_options)
      parser = parser("json")
      buffer = []
      sleep_sec = 0
      File.open(file).each_line do |line|
        ## if line is '# <number>' format, wait <number> seconds.
        if /^#\s+(\d+)$/ =~ line
          sleep_sec = $1.to_f
        else
          buffer.push(parser.parse(line))
        end
        if buffer.size >= options[:batch_size] || sleep_sec > 0
          client.send(target, buffer)
          buffer = []
        end
        if sleep_sec > 0
          sleep sleep_sec
          sleep_sec = 0
        end
      end

      wrap do
        client.send(target, buffer) if buffer.size > 0
      end

    end

    desc "replay_with_time TARGET FILE", "Send saved events in FILE to TARGET"
    option :time_key, :type => :string, :default => nil, :desc => "output key name for event time (default: nil. [time]\t[log] format is assumed)"
    option :time_format, :type => :string, :default => '%Y/%m/%d %H:%M:%S', :desc => "output time format (default: '2013/05/14 17:57:59')"
    def replay_with_time(target, file)
      client = client(parent_options)

      processed_file = file + "_processed"
      parser = parser("json")
      Norikra::Helper::LogReader.process(file, processed_file, options)
      start_time = Time.now
      buffer = []
      File.open(processed_file).each_line do |line|
        log = parser.parse(line)
        buffer.push(log)
        puts log
        if log['flush']
          client.send(target, buffer) if buffer.size > 0
          buffer = []
          if log['wait_till']
            puts "sleeping #{[log['wait_till'] - (Time.now - start_time),0].max} seconds"
            sleep [log['wait_till'] - (Time.now - start_time),0].max
          end
        end
      end
    end

  end
  
  class Target < Norikra::Client::Target

    desc "see TARGET", "See incoming events for the TARGET"
    option :format, :type => :string, :default => 'json', :desc => "format of output data per line of stdout [json(default), ltsv]"
    option :time_key, :type => :string, :default => 'time', :desc => "output key name for event time (default: time)"
    option :time_format, :type => :string, :default => '%Y/%m/%d %H:%M:%S', :desc => "output time format (default: '2013/05/14 17:57:59')"
    def see(target)

      res = Net::HTTP.get(options[:host],"/stat/dump",options[:http_port])
      stats = JSON.parse(res)
      if (target_info = stats['targets'].select{  |i| i['name'] == target}.first).size == 0 
        STDERR.puts "No such target"
        exit 1
      end

      if target_info['fields'].size == 0
        STDERR.puts "No fields registered"
        exit 1
      end

      query = %(SELECT #{target_info['fields'].map{  |k,v| "nullable(#{k})" }.join(',')} FROM #{target_info['name']})
      STDERR.puts "Registering query:" + query

      invoke Query, ["test", query], parent_options
      
    end
  end

  class HelperCLI < Norikra::Client::CLI
    class_option :http_port, :type => :numeric, :default => 26578
    
    desc "query CMD ...ARGS", "manage queries"
    subcommand "query", Query

    desc "event CMD ...ARGS", "send/fetch events"
    subcommand "event", Event

    desc "target CMD ...ARGS", "manage targets"
    subcommand "target", Target

  end
  
end

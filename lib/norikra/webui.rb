require 'sinatra/base'
require 'sinatra/json'
require 'norikra/client'
require 'json'
require 'dotenv'

module NorikraHelper
  class WebUI < Sinatra::Base
    QUERY_NAME_PREFIX = "norikra-tmp-"
    QUERY_GROUP = "norikra-helper"

    set :public_folder, File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'public'))
    set :views, File.absolute_path(File.join(File.dirname(__FILE__), '..', '..','views'))
    set :erb, escape_html: true

    enable :sessions

    configure :production, :development do
      Dotenv.load
      set :norikra_host, ENV['NORIKRA_HOST'] || 'localhost'
      set :norikra_rpc_port, ENV['NORIKRA_RPC_PORT'] || 26571
      set :norikra_http_port, ENV['NORIKRA_HTTP_PORT'] || 26578

      enable :logging
    end
    
    configure :development do
      require 'sinatra/reloader'
      register Sinatra::Reloader
    end
    
    def url_for(ref)
      "#{request.script_name}#{ref}"
    end

    
    def logging(handler, args=[], opts={})
      logger.info "handler: #{handler.to_s}, args: #{args} "

      begin
        yield
      rescue Norikra::RPC::ClientError => e
        logger.info "WebUI #{e.class}: #{e.message}"
        if opts[:on_error_hook]
          logger.info "rr"
          opts[:on_error_hook].call(e.class, e.message)
        else
          halt 400, e.message
        end
      rescue => e
        logger.error "WebUI #{e.class}: #{e.message}"
        e.backtrace.each do |t|
          logger.error "  " + t
        end
        if opts[:on_error_hook]
          opts[:on_error_hook].call(e.class, e.message)
        else
          halt 500, e.message
        end
      end
    end

    def client
      Norikra::Client.new(settings.norikra_host, settings.norikra_rpc_port) # TODO
    end

    def get_target_info(target)
      res = Net::HTTP.get(settings.norikra_host,"/stat/dump", settings.norikra_http_port) ## ToDo
      stats = JSON.parse(res)
      if (target_info = stats['targets'].select{  |i| i['name'] == target}.first).size == 0 
        halt 404, "target '#{target}' not found"
      end

      target_info
    end
    
    get '/' do
      @page = "summary"

      input_data,session[:input_data] = session[:input_data],nil

      queries = client.queries
      engine_targets = client.targets
      targets = engine_targets.map{|t|
        {
          name: t['name'],
          auto_field: t['auto_field'],
          fields: [],
          modified: nil
        }
      }

      erb :index, layout: :base, locals: {
            input_data: input_data,
            shut_off_mode: nil,
            stat: nil,
            queries: queries,
            pool: nil,
            targets: targets
          }
    end

    post '/close' do
      target_name = params[:target]
      logging(:close, [target_name]) do
        client.close(target_name)
        redirect url_for('/')
      end
    end

    post '/register' do
      query_name,query_group,expression = params[:query_name], params[:query_group], params[:expression]
      
      error_hook = lambda{ |error_class, error_message|
        session[:input_data] = {
         query_add: {
            query_name: query_name, query_group: query_group, expression: expression,
            error: error_message,
          },
        }
        redirect url_for("/#query_add")
      }

      if query_group.nil? || query_group.empty?
        query_group = nil
      end

      logging(:register, [query_name, query_group, expression],  on_error_hook: error_hook) do 
        if query_name.nil? || query_name.empty?
          raise Norikra::RPC::ClientError, "Query name MUST NOT be blank"
        end

        client.register(query_name, query_group,  expression)
        redirect url_for("/#queries")
      end

    end


    post '/json/test_query' do
      expression = params[:expression]
      query_name = QUERY_NAME_PREFIX + "#{$$}_#{Time.now.to_i}"
      query_group = QUERY_GROUP
      session[:input_data] = {  query_name: query_name, expression: expression }

      error_hook_json = lambda{ |error_class, error_message|
        halt 400,  error_message
      }

      logging(:register, [query_name, query_group, expression],  on_error_hook: error_hook_json) do 
        client.register(query_name, query_group,  expression)
        json  :query_name => query_name 
      end

    end
    
    post '/replace' do
      query_name,query_group,expression = params[:query_name], params[:query_group], params[:expression]
      current_query = client.queries.select{  |q| q['name'] == query_name}.first

      error_hook = lambda{ |error_class, error_message|
        session[:input_data] = {
          query_replace: {
            query_name: query_name, query_group: query_group, expression: expression,
            error: error_message,
          },
        }
        redirect url_for("/#queries")
      }

      unless current_query
        error_hook.call(nil, "Query with name: #{query_name} does not exist")
      end

      logging(:replace, [query_name,query_group,expression], on_error_hook: error_hook ) do
        client.deregister(query_name)
        client.register(query_name, current_query['group'], expression)
        redirect url_for("/#queries")
      end
      
    end

    post '/deregister' do
      query_name = params[:query_name]
      logging(:deregister, [query_name]) do
        client.deregister(query_name)
        redirect url_for("/#queries")
      end
    end
    
    get '/json/query/:name' do
      query_name = params[:name]
      logging(:json_query, [query_name]) do
        query = client.queries.select{|q| q['name'] == query_name}.first
        if query
          content = {
            name: query['name'],
            group: query['group'] || "(default)",
            targets: query['targets'],
            expression: query['expression']
#            events: engine.output_pool.fetch(query.name).size
          }
          json content
        else
          halt 404
        end
      end
    end

    get '/json/event/:query' do
      query_name = params[:query]

      logging(:json_event, [query_name]) do
        puts query_name
        json client.event(query_name)
      end
    end
    
    post '/suspend' do
      query_name = params[:query_name]
      logging(:suspend, [query_name]) do
        client.suspend(query_name)
        redirect url_for("/#queries")
      end
    end

    post '/resume' do
      query_name = params[:query_name]
      logging(:resume, [query_name]) do
        client.resume(query_name)
        redirect url_for("/#queries")
      end
    end

    get '/json/:target/see' do
      target = params[:target]
      target_info = get_target_info(target)
      
      if target_info['fields'].size == 0
        halt 404, "Could not find fields for target: '#{target}'"
      end

      query = %(SELECT #{target_info['fields'].map{  |k,v| "nullable(#{k})" }.join(',')} FROM #{target_info['name']})
      query_name = QUERY_NAME_PREFIX + "#{$$}_#{Time.now.to_i}"
      json :query_name =>  query_name, :expression => query
    end

    get '/json/target/:name' do

      target_info = get_target_info(params[:name])
      
      target_info['fields'] = target_info['fields'].values
      json target_info
    end
    
  end
end

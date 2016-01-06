require 'sinatra/base'
require 'norikra/client'

module NorikraHelper
  class WebUI < Sinatra::Base
    set :public_folder, File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'public'))
    set :views, File.absolute_path(File.join(File.dirname(__FILE__), '..', '..','views'))
    set :erb, escape_html: true

    def url_for(ref)
      "#{request.script_name}#{ref}"
    end

    
    def logging(type, handler, args=[], opts={})
      if type == :manage
        debug("WebUI"){ { handler: handler.to_s, args: args } }
      else
        trace("WebUI"){ { handler: handler.to_s, args: args } }
      end

      begin
        yield
      rescue Norikra::ClientError => e
        logger.info "WebUI #{e.class}: #{e.message}"
        if opts[:on_error_hook]
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
      Norikra::Client.new('localhost', 26571) # TODO
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


    post '/register' do
      query_name,query_group,expression = params[:query_name], params[:query_group], params[:expression]

      error_hook = lambda{ |error_class, error_message|
        session[:input_data] = {
          query_edit: {
            query_name: query_name, query_group: query_group, expression: expression,
            error: error_message,
          },
        }
        redirect url_for("/#query_add")
      }

      if query_name.nil? || query_name.empty?
        raise Norikra::ClientError, "Query name MUST NOT be blank"
      end
      if query_group.nil? || query_group.empty?
        query_group = nil
      end
      client.register(query_name, query_group,  expression)
      redirect url_for("/#queries")
    end

  end
end

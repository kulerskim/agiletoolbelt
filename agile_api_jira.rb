require 'faraday'
require "json"

module AgileToolBelt

  # = AgileApiJira
  # Provider for JIRA API
  class AgileApiJira

    def initialize(config)
      @config=config
      @conn = Faraday.new(:url => @config['address']) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        #faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        faraday.proxy @config["proxy"]
      end
    end

    def transition(issue, transition_name)

      response = @conn.get do |req|
        req.url "/rest/api/latest/issue/#{issue}/transitions?expand=transitions.fields"
        req.headers['Authorization'] = "Basic #{@config['auth']}"
      end

      parsed = handle_response(response)

      parsed["transitions"].each do |transition|
        if transition["name"].upcase == transition_name.upcase
          @transition_id = transition["id"]
          if transition["assignee"] != nil
            @assignee = '"fields":{ "assignee": { "name": "'+@config['user']+'" } },'
          else
            @assignee = ''
          end
        end
      end

      if @transition_id == nil
        raise "Wrong transition"
      end

      response = @conn.post do |req|
        req.url "/rest/api/latest/issue/#{issue}/transitions?expand=transitions.fields"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = "Basic #{@config['auth']}"
        req.body = '{ '+@assignee+' "transition" :{ "id": "'+@transition_id+'" } }'
      end

      handle_response(response)

      puts "OK"
      return 0
    rescue Exception
      puts "Error: #{$!}"
      exit 1
    end

    private
    def handle_response(response)
      if response.status >= 400
        errors = JSON.parse(response.errors)
        raise  errors.join()
      else
        if response.status == 204
          return 0
        else
          parsed = JSON.parse(response.body)
          return parsed
        end
      end
    end

  end
end


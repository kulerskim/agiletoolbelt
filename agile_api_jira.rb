require 'faraday'
require "json"

module AgileToolBelt

  # = AgileApiJira
  # Provider for JIRA API
  class AgileApiJira

    def transition(config, issue, transition_name)
      conn = Faraday.new(:url => config['address']) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        #faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        faraday.proxy ENV['http_proxy']
      end

      response = conn.get do |req|
        req.url "/rest/api/latest/issue/#{issue}/transitions?expand=transitions.fields"
        req.headers['Authorization'] = "Basic #{config['auth']}"
      end

      parsed = handle_response(response)

      parsed["transitions"].each do |transition|
        if transition["name"].upcase == transition_name.upcase
          @transition_id = transition["id"]
        end
      end

      if @transition_id == nil
        raise "Wrong transition"
      end

      response = conn.post do |req|
        req.url "/rest/api/latest/issue/#{issue}/transitions?expand=transitions.fields"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = "Basic #{config['auth']}"
        req.body = '{ "transition" :{ "id": "'+@transition_id+'" } }'
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
        errors = JSON.parse(response.errorMessages)
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


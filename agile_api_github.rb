module AgileToolBelt

  require "faraday"
  require "json"

  #
  # = AgileApiGithub provides API communication with github API
  # currently supporting test, open & close pull requests
  class AgileApiGithub

    # = initialize
    # just setup connection and shared variables
    def initialize config
      @config = config

      git_config = `git config --get remote.origin.url`.split(":")[1].split(".")[0].split("/")
      @config["rep_owner"] = git_config[0];
      @config["rep_name"] = git_config[1];

      @conn = Faraday.new(:url => @config["url"],
                          :proxy => @config["proxy"],
                          :ssl => {:verify => false}) do |faraday|
        faraday.request  :url_encoded
        faraday.adapter  Faraday.default_adapter
      end
      @api_uri = "/repos/#{@config["rep_owner"]}/#{@config["rep_name"]}"
    end

    # = test
    # Simply tries to connect to repo using configured variables
    def test

      response = @conn.get do |req|
        req.url(@api_uri)
        req.headers['Authorization'] = "token #{@config["git_token"]}"
      end

      raise "Invalid response code (#{response.status})" if response.status != 200

      data = JSON.parse response.body
      puts "Connection to #{data["name"]} successful"

      return 0

    rescue Exception => e
      connection_failed e
      return 1
    end

    # = Starts a new pull request
    # fails if already opened request for given branch name exists
    def start_review branch_name
      @pulls = get_pull_requests  branch_name
      @pulls.each do |pull|
        raise "Opened pull request for #{branch_name} already exists (id=#{pull["number"]})" if pull["head"]["ref"]==branch_name && pull["state"]=="open"
      end

      pull_request = {
          "title"=>"The #{branch_name} code review",
          "body"=>"Requesting code review",
          "head"=>branch_name,
          "base"=>"develop"
      }

      response = @conn.post do |req|
        req.url "#{@api_uri}/pulls"
        req.headers['Authorization'] = "token #{@config["git_token"]}"
        req.body = pull_request.to_json
      end
      handle_response response, 201

      puts "Pull request for #{branch_name} opened"
      return 0

    rescue Exception => e
      connection_failed e
      return 1
    end

    # = Closes existing pull request
    # Fails if there is none or more than one opened pull requests for this branch
    def finish_review branch_name

      number = false
      @pulls = get_pull_requests  branch_name
      @pulls.each do |pull|
        if pull["head"]["ref"]==branch_name && pull["state"]=="open"
          raise "There is more then one opened pull request for this branch, clean it up by yourself!" if number
          number = pull["number"]
        end
      end

      raise "Could not find opened pull request for #{branch_name}" if not number

      data = {"state"=>"closed"}

      response = @conn.patch do |req|
        req.url "#{@api_uri}/pulls/#{number}"
        req.headers['Authorization'] = "token #{@config["git_token"]}"
        req.body = data.to_json
      end
      handle_response response

      puts "Pull request #{number} for #{branch_name} closed"
      return 0

    rescue Exception => e
      connection_failed e
      return 1
    end

    private

      # = connection_failed
      # Standarize output of problems
      def connection_failed exception
        puts "Failed due to #{exception.message}"
        puts "Exception details:\n\n#{exception.to_s}"
      end

      # = get_pull_requests
      # return parsed pull requests or raise an exception
      def get_pull_requests branch_name
        response = @conn.get do |req|
          req.url "#{@api_uri}/pulls"
          req.headers['Authorization'] = "token #{@config["git_token"]}"
        end
        handle_response response
      end

      # = handle response
      # Trying to parse response body to JSON and find some error messages
      # When found or response return status doesn't match expected raises an Exception
      # otherwise returns JSON parsed Object
      def handle_response response, expected_code=200

        errors = []

        begin
          parsed = JSON.parse response.body
        rescue
          errors.push "Could not parse response body"
        end

        if parsed.instance_of? Hash

          puts "github message: #{parsed["message"]}" if parsed.has_key? "message"
          if parsed.has_key? "errors"
            parsed["errors"].each do |error|
              errors.push "github error: #{error["message"]}"
            end
          end
        end

        if response.status != expected_code
          errors.unshift "HTTP: Invalid response code (#{response.status}) when fetching pull request"
        end

        return parsed if errors.empty?

        raise errors.join "\n"
      end
  end
end

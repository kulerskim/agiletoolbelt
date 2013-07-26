#
#  = AgileToolBelt
# This module provides handy tool to comunicate with remote APIs
# Each API should be registered in available_apis hash and included in
# separate file.
#
module AgileToolBelt

  class Runner

    # = available_apis
    # a list of accepted first argument values.
    # appropriate file should be attached
    def available_apis
      {
        :github=>'Github',
        :jira=>'Jira'
      }
    end

    def initialize(args)

      @api = args.shift.to_sym
      @cmd = args.shift.to_sym
      @params = args

      if not available_apis.keys.include? @api
        puts "API #{@api} not available"
        return
      end

      require_relative "agile_api_#{@api}.rb"

      @class_name = "AgileApi#{available_apis[@api]}"

      if not class_exists? @class_name
        puts "Class #{@class_name} is not defined"
        return
      end

      @api_instance = AgileToolBelt.const_get(@class_name).new

      if @params.size != @api_instance.method(@cmd).arity
        puts "Incorrect number of parameters for #{@cmd}"
        return
      end

      if not @api_instance.respond_to? @cmd
        puts "API #{@api} has not defined #{@cmd}"
        return
      end

      @api_instance.send @cmd, *@params

    end

    def class_exists?(class_name)
      _class = AgileToolBelt.const_get(class_name)
      return _class.is_a?(Class)
    rescue NameError
      puts _class
      return false
    end
  end

  tool_belt = Runner.new ARGV
end

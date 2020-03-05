module Praxis
  module Docs
    module OpenApi
      class InfoObject
        attr_reader :info, :version
        def initialize(version: , api_definition: )
          @version = version
          @info = api_definition
          raise "OpenApi docs require a 'Title' for your API." unless @info[:title]
        end

        def dump
          {
            title: info[:title],
            description: info[:description],
            #termsOfService: ???,
            #contact: {}, #TODO
            #license: {}, #TODO
            version: version,
            :'x-name' => info[:name],
            :'x-description' => info[:description]
          }
        end
      end
    end
  end
end

module Praxis
  module Docs
    module OpenApi
      class InfoObject
        attr_reader :info, :version
        def initialize(version: , api_definition_info: )
          @version = version
          @info = api_definition_info
          raise "OpenApi docs require a 'Title' for your API." unless info.title
        end

        def dump
          {
            title: info.title,
            description: info.description,
            #termsOfService: ???,
            #contact: {}, #TODO
            #license: {}, #TODO
            version: version,
            :'x-name' => info.name
          }
        end
      end
    end
  end
end

module Praxis
  module Docs
    module OpenApi
      class TagObject
        attr_reader :name, :info
        def initialize(name:,info: )
          @name = name
          @info = info
        end

        def dump
          {
            name: name,
            description: info[:description],
            #externalDocs: ???,
          }
        end
      end
    end
  end
end

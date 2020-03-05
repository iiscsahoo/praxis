module Praxis
  module Docs
    module OpenApi
      class MediaTypeObject
        attr_reader :schema, :example
        def initialize(schema:, example:)
          @schema = schema
          @example = example
        end

        def dump
          {
           schema: schema,
           example: example,   
           # encoding: TODO SUPPORT IT maybe be great/necessary for multipart
          }
        end
      end
    end
  end
end

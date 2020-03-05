require_relative 'schema_object'

module Praxis
  module Docs
    module OpenApi
      class RequestBodyObject
        # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#request-body-object
        attr_reader :info 
        def initialize(info:)
          @info = info
        end

        def dump
          h = {}
          h[:description] = info[:description] if info[:description]
          h[:required] = info[:required] || false

          # OpenApi wants a set of bodies per MediaType/Content-Type
          # For us there's really only one schema (regardless of encoding)...
          # so we'll show all the supported MTs...but repeating the schema
          dumped_schema = SchemaObject.new(info: info).dump_schema
          # Key string (of MT) , value MTObject
          content_hash = info[:examples].each_with_object({}) do |(handler, example_hash),accum|
            content_type = example_hash[:content_type]
            accum[content_type] = MediaTypeObject.new(
              schema: dumped_schema, # Every MT will have the same exact type..oh well
              example: info[:examples][handler][:body],
            ).dump
          end
          # TODO! Handle Multipart types! they look like arrays now in the schema...etc
          h[:content] = content_hash
          h
        end
      end
    end
  end
end

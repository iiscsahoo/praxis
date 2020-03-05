require_relative 'media_type_object'

module Praxis
  module Docs
    module OpenApi
      class ResponseObject
        # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#response-object
        attr_reader :info
        def initialize(info:)
          @info = info
        end

        def dump_response_headers_object( headers )
          puts "WARNING!! Finish this. It seems that headers for responses are never set in the hash??"
          headers.each_with_object({}) do |(name,data),accum|
            # data is a hash with :value and :type keys
            # How did we say in that must match a value in json schema again??
            accum[name] = {
              schema: SchemaObject.new(info: data[:type])
              # allowed values:  [ data[:value] ] ??? is this the right json schema way?
            }
          end
        end

        def dump
            data = { 
              description: info[:description] || ''
            }
            if headers_object = dump_response_headers_object( info[:headers] )
              data[:headers] = headers_object
            end

            if payload = info[:payload]
              dumped_schema = SchemaObject.new(info: payload).dump_schema
              # Key string (of MT) , value MTObject
              content_hash = payload[:examples].each_with_object({}) do |(handler, example_hash),accum|
                content_type = example_hash[:content_type]
                accum[content_type] = MediaTypeObject.new(
                  schema: dumped_schema, # Every MT will have the same exact type..oh well
                  example: payload[:examples][handler][:body],
                ).dump
              end
              data[:content] = content_hash
            end

            # if payload = info[:payload]
            #   body_type= payload[:id]
            #   raise "WAIT! response payload doesn't have an existing id for the schema!!! (do an if, and describe it if so)" unless body_type
            #   data[:schema] = {"$ref" => "#/definitions/#{body_type}" }
            # end
  
            
            # TODO: we do not support 'links'
            data
        end
      end
    end
  end
end

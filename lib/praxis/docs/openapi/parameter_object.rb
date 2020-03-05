require_relative 'schema_object'

module Praxis
  module Docs
    module OpenApi
      class ParameterObject
        # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#parameter-object
        attr_reader :location, :name, :info 
        def initialize(location: , name: , info:)
          @location = location
          @name = name
          @info = info
        end

        def dump
          # Fixed fields
          h = { name: name, in: location }
          h[:description] = info[:description] if info[:description]
          h[:required] = info[:required] || false
          # h[:deprecated] = false
          # h[:allowEmptyValue] ??? TODO: support in Praxis

          # Other supported attributes
          # style
          # explode
          # allowReserved
          
          # Now merge the rest schema and example
          # schema
          # example
          # examples (Example and Examples are mutually exclusive)
          schema = SchemaObject.new(info: info)
          h[:schema] = schema.dump_schema
          # Note: we do not support the 'content' key...we always use schema
          h[:example] = schema.dump_example
          h
        end

        def self.convert_parameter_location( praxis )
          # FIXME: We are not supporting the cookie one
          case praxis.to_sym
          when :url
            :path
          when :query
            :query
          when :header
            :header
          else
            raise "Wait! unknown parameter location received: #{praxis}"
          end
        end
  
        # def self.dump_single_parameters_object( location: , name: , info:  )
        #   # Fixed fields
        #   h = { name: name, in: location }
        #   h[:description] = info[:description] if info[:description]
        #   h[:required] = info[:required] || false
        #   # h[:deprecated] = false
        #   # h[:allowEmptyValue] ??? TODO: support in Praxis

        #   # Other supported attributes
        #   # style
        #   # explode
        #   # allowReserved
          
        #   # Now merge the rest schema and example
        #   # schema
        #   # example
        #   # examples (Example and Examples are mutually exclusive)
        #   schema = SchemaObject.new(info: info)
        #   h[:schema] = schema.dump_schema
        #   h[:example] = schema.dump_example
        #   h
        # end

        def self.dump_parameters_object( headers: , params: , payload: )
          output = []
          # An array, with one hash per param inside  
          (headers||{}).each_with_object(output) do |(name, info), out|
            out << ParameterObject.new( location: 'header', name: name, info: info ).dump
          end
  
          (params||{}).each_with_object(output) do |(name, info), out|
            in_type = convert_parameter_location( info[:source] )
            out << ParameterObject.new( location: in_type, name: name, info: info ).dump
          end
  
  #        # TODO!!!
  #        # If payload is multipart...then something's going on...
  #        # If it is a "form" ... then it is different...
  #        (payload||{}).each_with_object(output) do |(name, info), out|
  #          {
  #            name: name,
  #            in: 'body',
  #            description: info[:description],
  #            required: info[:required],
  #            schema: {}# TODO!!!!
  #          }
  #        end
          output
        end
  
        def self.process_parameters( action )
          headers = action[:headers] ? action[:headers][:type][:attributes] : {}
          params = action[:params] ? action[:params][:type][:attributes] : {}

          dump_parameters_object( headers: headers, params: params, payload: action[:payload])
        end
      end
    end
  end
end

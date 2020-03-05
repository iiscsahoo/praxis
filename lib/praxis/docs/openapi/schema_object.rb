module Praxis
  module Docs
    module OpenApi
      class SchemaObject
        # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#schema-object
        attr_reader :info
        def initialize(info:)
          @info = info # Info about a type
        end

        def dump_example
          {}
        end
        def dump_schema
          h = {
            type: convert_family_to_json_type( info[:type] )
            #TODO: format?
          }
          # required prop!!!??
          h[:default] = info[:default] if info[:default]
          h[:pattern] = info[:regexp] if info[:regexp]
          # TODO: there are other possible things we can do..maximum, minimum...etc
  
          if h[:type] == 'array'
            # FIXME: ... does items expect a "schema" key? and example?...
            h[:items] = SchemaObject.new(info: info[:type][:member_attribute] ).dump_schema
          end
          h
        end
        
        def convert_family_to_json_type( praxis_type )
          case praxis_type[:family].to_sym
          when :string
            :string
          when :hash
            :object
          when :array
            :array
          when :numeric
            case praxis_type[:id]
            when 'Attributor-Integer'
              :integer
            when 'Attributor-BigDecimal'
              :integer
            when 'Attributor-Float'
              :number
            end
          when :temporal
            :string
          when :boolean
            :boolean
          else
            raise "Unknown praxis family type: #{praxis_type[:family]}"
          end
        end

      end
    end
  end
end

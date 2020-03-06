module Praxis
  module Docs
    module OpenApi
      class SchemaObject
        # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#schema-object
        attr_reader :info
        def initialize(info:)
          
          # NOTE: FIXME TODO: we're trying to get the member attribute of the info for collections
          # but somehow info from responses are weird...and non-collections do not have a type...
          @info = \
            if info.key?(:type) # Info about a type
              info
            # HACK, collections do not have a top-level type...so get it from the member_attr
            elsif info[:member_attribute]
              @is_array = true
              info[:member_attribute] #??
            else
              nil
            end
        end

        def dump_example
          {}
        end
        def dump_schema
          # TODO: FIXME: return a generic object type if the passed info was weird. 
          return { type: :object } unless info

          h = {
            #type: convert_family_to_json_type( info[:type] )
            type: info[:type]
            #TODO: format?
          }
          # required prop!!!??
          h[:default] = info[:default] if info[:default]
          h[:pattern] = info[:regexp] if info[:regexp]
          # TODO: there are other possible things we can do..maximum, minimum...etc
  
          if h[:type] == :array
            # FIXME: ... hack it for MultiPart arrays...where there's no member attr
            member_type =  info[:type][:member_attribute]
            unless member_type
              member_type = { family: :hash}
            end
            h[:items] = SchemaObject.new(info: member_type ).dump_schema
          end
          h
        rescue => e
          binding.pry
          puts "asdfa"
        end
        
        def convert_family_to_json_type( praxis_type )
          case praxis_type[:family].to_sym
          when :string
            :string
          when :hash
            :object
          when :array #Warning! Multipart types are arrays!
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

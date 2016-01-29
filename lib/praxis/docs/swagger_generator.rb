module Praxis
  module Docs

    class SwaggerGenerator< Generator
      API_DOCS_DIRNAME = 'docs/swagger'


      def initialize(root)
        require 'yaml'
        @resources_by_version =  Hash.new do |h,k|
          h[k] = Set.new
        end
        initialize_directories(root)

        Attributor::AttributeResolver.current = Attributor::AttributeResolver.new
        collect_infos
        collect_resources
        collect_types
      end

#      def save!
#        # Restrict the versions listed in the index file to the ones for which we have at least 1 resource
#        write_index_file( for_versions: resources_by_version.keys )
#        resources_by_version.keys.each do |version|
#          write_version_file(version)
#        end
#      end

      private

      def write_index_file( for_versions:  )
      end

      def write_version_file( version )

        version_info = infos_by_version[version]
        # Hack, let's "inherit/copy" all traits of a version from the global definition
        # Eventually traits should be defined for a version (and inheritable from global) so we'll emulate that here
        version_info[:traits] = infos_by_version[:traits]
        dumped_resources = dump_resources( resources_by_version[version] )
        found_media_types =  resources_by_version[version].select{|r| r.media_type}.collect {|r| r.media_type.describe }

        collected_types = Set.new
        collect_reachable_types( dumped_resources, collected_types )
        found_media_types.each do |mt|
          collect_reachable_types( { type: mt} , collected_types )
        end

        dumped_info = dump_info_object( version, version_info[:info] )
        dumped_schemas = dump_schemas( collected_types )

        full_data = {
          swagger: "2.0",
          info: dumped_info,
          host: version_info[:info][:endpoint],
          basePath: templatize( version_info[:info][:base_path] ),
          schemes: ['http','https'], # TODO! might want to add that to Praxis
          consumes: normalize_media_types( version_info[:info][:consumes] ),
          produces: normalize_media_types( version_info[:info][:produces] ),
          paths: dump_paths( dumped_resources ),
          definitions: convert_to_definitions_object( dumped_schemas ),

          responses: {}, #TODO!! what do we get here? the templates?...need to transform to "Responses Definitions Object"
          securityDefinitions: {}, # NOTE: No security definitions in Praxis
          security: [], # NOTE: No security definitions in Praxis
          tags: convert_traits_to_tags( version_info[:traits] || [] ) #Note: is this the right thing to do?
        }
        if parameter_object = convert_to_parameter_object( version_info[:info][:base_params] )
          full_data[:parameters] = parameter_object
        end
        puts JSON.pretty_generate( full_data )
        # Write the file
        version_file = ( version == "n/a" ? "unversioned" : version )
        filename = File.join(doc_root_dir, "swagger")

        puts "Generating swagger file : #{filename} (json and yml) "
        json_data = JSON.pretty_generate(full_data)
        File.open(filename+".json", 'w') {|f| f.write(json_data)}
        converted_full_data = JSON.parse( json_data ) # So symbols disappear
        File.open(filename+".yml", 'w') {|f| f.write(YAML.dump(converted_full_data))}
      end

      def templatize( string )
        # TODO: substitute ":params_like_so" for {params_like_so}
        converted  = Mustermann.new(string).to_templates.first
        puts "TEMPLATE: #{string} -> #{converted}"
        converted
      end

      def dump_info_object( version, info )
        full = {
          title: info[:title],
          description: info[:description],
          #termsOfService: ???,
          #contact: {}, #TODO
          #license: {}, #TODO
          version: version,
          :'x-name' => info[:name]
        }
      end

      def normalize_media_types( mtis )
        mtis.collect do |mti|
           MediaTypeIdentifier.load(mti).to_s
         end
      end

      def convert_to_definitions_object( schemas )
        # TODO!! actually convert each of them
        puts "TODO! convert to definitions object"
        schemas
      end
      def convert_to_parameter_object( params )
        # TODO!! actually convert each of them
        puts "TODO! convert to parameter object"
        params
      end

      def convert_traits_to_tags( traits )
        traits.collect do |name, info|
          { name: name, description: info[:description] }
        end
      end

      def dump_paths( resources )
        accum = {}
        resources.each do |id, info|
          dump_resource_paths( id, info , accum )
        end
        accum
      end

      def dump_resource_paths( id, resource , accum )
        # Return a hash with a key for each path for each action/route
        resource[:actions].each do |action|
          raise "Fix multiple urls in an action! (by duplicating info)" if action[:urls].size > 1
          url = action[:urls].first
          _path = templatize( url[:path] )
          _verb = url[:verb].downcase
          unless accum[_path]
            accum[_path] = {}
          end
          working  = accum[_path]
          # Let's fill in verb stuff within the working hash
          raise "VERB #{_verb} already defined for #{id}!?!?!" if working[ _verb ]
          working[_verb] = dump_operation_object( url: url, action: action )
          #working[:parameters] = [] # We always unlroll the parameters...we could potentially try to unroll them?...
        end
      end


      def dump_operation_object( url: , action: )
        header_attributes = action[:headers] ? action[:headers][:type][:attributes] : {}
        param_attributes = action[:params] ? action[:params][:type][:attributes] : {}
        x= {
          summary: action[:name], #NOTE: Should we just leave it blank?
          description: action[:description],
          #TODO? operationId:
          #TODO? consumes:
          #TODO? produces:
          #TODO? schemes:
          #TODO? security:
          #TODO? deprecated:
          responses: dump_responses_object( action[:responses] )
         }

         x[:tags] = action[:traits] if action[:traits]
         if parameters_object = dump_parameters_object( headers: header_attributes, params: param_attributes, payload: action[:payload])
           x[:parameters] = parameters_object unless parameters_object.empty?
         end

#         puts JSON.pretty_generate(x)
         x
      end

      def dump_responses_object( responses )
        responses.each_with_object({}) do |(name, info), hash|
          data = { description: info[:description] || "" }
          if payload = info[:payload]
            body_type= payload[:id]
            raise "WAIT! response payload doesn't have an existing id for the schema!!! (do an if, and describe it if so)" unless body_type
            data[:schema] = {"$ref" => "#/definitions/#{body_type}" }
          end

#          data[:schema] = ???TODO!!
          if headers_object = dump_response_headers_object( info[:headers] )
            data[:headers] = headers_object
          end
          if info[:payload] && ( examples_object = dump_response_examples_object( info[:payload][:examples] ) )
            data[:examples] = examples_object
          end
          hash[info[:status]] = data
        end
      end
      def dump_response_headers_object( headers )
        puts "WARNING!! Finish this. It seems that headers for responses are never set in the hash??"
        unless headers.empty?
          binding.pry
          puts headers
        end
      end

      def dump_response_examples_object( examples )
        examples.each_with_object({}) do |(name, info), hash|
          hash[info[:content_type]] = info[:body]
        end
      end

      def dump_parameters_object( headers: , params: , payload: )
        output = []
        # An array, with one hash per param inside

        (headers||{}).each_with_object(output) do |(name, info), out|
          h = dump_single_parameters_object( name, info )
          h[:in] = "header"
          out << h
        end

        (params||{}).each_with_object(output) do |(name, info), out|
          h = dump_single_parameters_object( name, info )
          h[:in] = convert_parameter_location( info[:source] )
          out << h
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

      def convert_parameter_location( praxis )
        case praxis.to_sym
        when :url
          :path
        when :body
          :body
        when :query
          :query
        when :header
          :header
        else
          raise "Wait! unknown parameter location received: #{praxis}"
        end
      end
      def dump_single_parameters_object( name, info )
        h = { name: name }
        h[:description] = info[:description] if info[:description]
        h[:required] = info[:required] || false
        h.merge!( dump_type_object( info ))
      end

      def dump_type_object( info )
        h = {
          type: convert_family_to_json_type( info[:type] )
          #TODO: format?
        }
        h[:default] = info[:default] if info[:default]
        h[:pattern] = info[:regexp] if info[:regexp]
        # TODO: there are other possible things we can do..maximum, minimum...etc

        if h[:type] == 'array'
          h[:items] = dump_type_info( info[:type][:member_attribute] ) #??is this correct?
        end
        h
      end
      def convert_family_to_json_type( praxis_type )
        case praxis_type[:family].to_sym
        when :string
          :string
        when :hash
          :object
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
#      def dump_resources( resources )
#        resources.each_with_object({}) do |r, hash|
#          # Do not report undocumentable resources
#          next if r.metadata[:doc_visibility] == :none
#          context = [r.id]
#          resource_description = r.describe(context: context)
#
#          # strip actions with doc_visibility of :none
#          resource_description[:actions].reject! { |a| a[:metadata][:doc_visibility] == :none }
#
#          # Go through the params/payload of each action and augment them by
#          # adding a generated example (then stick it into the description hash)
#          r.actions.each do |action_name, action|
#            # skip actions with doc_visibility of :none
#            next if action.metadata[:doc_visibility] == :none
#
#            action_description = resource_description[:actions].find {|a| a[:name] == action_name }
#          end
#
#          hash[r.id] = resource_description
#        end
#      end
#
#      def dump_example_for(context_name, object)
#        example = object.example(Array(context_name))
#        if object.is_a? Praxis::Blueprint
#          example.render(view: :master)
#        elsif object.is_a? Attributor::Attribute
#          object.dump(example)
#        else
#          raise "Do not know how to dump this object (it is not a Blueprint or an Attribute): #{object}"
#        end
#      end

    end
  end
end

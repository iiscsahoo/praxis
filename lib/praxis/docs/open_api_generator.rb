require_relative 'openapi/info_object.rb'
require_relative 'openapi/server_object.rb'
require_relative 'openapi/paths_object.rb'
require_relative 'openapi/tag_object.rb'

module Praxis
  module Docs

    class OpenApiGenerator< Generator
      API_DOCS_DIRNAME = 'docs/openapi'

      # TODO: DELETE??
      def self.templatize( string )
        # substitutes ":params_like_so" for {params_like_so}
        converted  = Mustermann.new(string).to_templates.first
        #puts "TEMPLATE: #{string} -> #{converted}"
        converted
      end


      def initialize(root)
        require 'yaml'
        @resources_by_version =  Hash.new do |h,k|
          h[k] = Set.new
        end
        initialize_directories(root)

        Attributor::AttributeResolver.current = Attributor::AttributeResolver.new # ???
        #collect_infos no need, the
        @infos = ApiDefinition.instance.infos
        collect_resources
        collect_types
      end

      private

      # def collect_infos
      #   # All infos. Including keys for `:global`, "n/a", and any string version
      #   binding.pry
      #   @infos = ApiDefinition.instance.infos.each_with_object({}) do |(version,info), accum|
      #     accum[version] = info
      #   end
      # end


      def write_index_file( for_versions:  )
      end

      def write_version_file( version )
        ###### COPIED FROM BASE ####
        # version_info = infos_by_version[version]
        # # Hack, let's "inherit/copy" all traits of a version from the global definition
        # # Eventually traits should be defined for a version (and inheritable from global) so we'll emulate that here
        # version_info[:traits] = infos_by_version[:traits]
        dumped_resources = dump_resources( resources_by_version[version] )
        found_media_types =  resources_by_version[version].select{|r| r.media_type}.collect {|r| r.media_type.describe }

        # We'll start by processing the rendered mediatypes
        processed_types = Set.new(resources_by_version[version].select do|r|
          r.media_type && !r.media_type.is_a?(Praxis::SimpleMediaType)
        end.collect(&:media_type))

        newfound = Set.new
        found_media_types.each do |mt|
          newfound += scan_dump_for_types( { type: mt} , processed_types )
        end
        # Then will process the rendered resources (noting)
        newfound += scan_dump_for_types( dumped_resources, Set.new )

        # At this point we've done a scan of the dumped resources and mediatypes.
        # In that scan we've discovered a bunch of types, however, many of those might have appeared in the JSON
        # rendered in just shallow mode, so it is not guaranteed that we've seen all the available types.
        # For that we'll do a (non-shallow) dump of all the types we found, and scan them until the scans do not
        # yield types we haven't seen before
        while !newfound.empty? do
          dumped = newfound.collect(&:describe)
          processed_types += newfound
          newfound = scan_dump_for_types( dumped, processed_types )
        end
        ###### END OF COPIED FROM BASE ####
        # Here we have:
        # processed types: which includes mediatypes and normal types...real classes
        # processed resources for this version: resources_by_version[version]

        info_object = OpenApi::InfoObject.new(version: version, api_definition_info: @infos[version])
        # We only support a server in Praxis ... so we'll use the base path
        server_object = OpenApi::ServerObject.new( url: @infos[version].base_path )
        
        paths_object = OpenApi::PathsObject.new( resources: resources_by_version[version])

        full_data = {
          openapi: "3.0.2",
          info: info_object.dump,
          servers: [server_object.dump],
          paths: paths_object.dump,
          # responses: {}, #TODO!! what do we get here? the templates?...need to transform to "Responses Definitions Object"
          # securityDefinitions: {}, # NOTE: No security definitions in Praxis
          # security: [], # NOTE: No security definitions in Praxis
        }

        # Create the top level tags by:
        # 1- First adding all the resource display names (and descriptions)
        tags_for_resources = resources_by_version[version].collect do |resource|
          OpenApi::TagObject.new(name: resource.display_name, description: resource.description ).dump
        end
        full_data[:tags] = tags_for_resources
        # 2- Then adding all of the top level traits but marking them special with the x-traitTag (of Redoc)
        tags_for_traits = (ApiDefinition.instance.traits).collect do |name, info|
          OpenApi::TagObject.new(name: name, description: info.description).dump.merge(:'x-traitTag' => true)
        end
        unless tags_for_traits.empty?
          full_data[:tags] = full_data[:tags] + tags_for_traits
        end

        full_data[:components] = {
          schemas: reusable_schema_objects(processed_types)
        }
        # if parameter_object = convert_to_parameter_object( version_info[:info][:base_params] )
        #   full_data[:parameters] = parameter_object
        # end
        puts JSON.pretty_generate( full_data )
        # Write the file
        version_file = ( version == "n/a" ? "unversioned" : version )
        filename = File.join(doc_root_dir, "#{version_file}.openapi")

        puts "Generating Open API file : #{filename} (json and yml) "
        json_data = JSON.pretty_generate(full_data)
        File.open(filename+".json", 'w') {|f| f.write(json_data)}
        converted_full_data = JSON.parse( json_data ) # So symbols disappear
        File.open(filename+".yml", 'w') {|f| f.write(YAML.dump(converted_full_data))}
      end

      # def dump_info_object( version, info )
      #   full = {
      #     title: info[:title],
      #     description: info[:description],
      #     #termsOfService: ???,
      #     #contact: {}, #TODO
      #     #license: {}, #TODO
      #     version: version,
      #     :'x-name' => info[:name]
      #   }
      # end

      def normalize_media_types( mtis )
        mtis.collect do |mti|
           MediaTypeIdentifier.load(mti).to_s
         end
      end

      def reusable_schema_objects(types)
        types.each_with_object({}) do |(type), accum|
          the_type = \
            if type.respond_to? :as_json_schema
              type
            else # If it is a blueprint ... for now, it'd be through the attribute
              type.attribute
            end
          accum[type.id] = the_type.as_json_schema(shallow: false)
        end
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
      # def dump_response_headers_object( headers )
      #   puts "WARNING!! Finish this. It seems that headers for responses are never set in the hash??"
      #   unless headers.empty?
      #     binding.pry
      #     puts headers
      #   end
      # end

      def dump_response_examples_object( examples )
        examples.each_with_object({}) do |(name, info), hash|
          hash[info[:content_type]] = info[:body]
        end
      end


      def dump_resources( resources )
        resources.each_with_object({}) do |r, hash|
          # Do not report undocumentable resources
          next if r.metadata[:doc_visibility] == :none
          context = [r.id]
          resource_description = r.describe(context: context)

          # strip actions with doc_visibility of :none
          resource_description[:actions].reject! { |a| a[:metadata][:doc_visibility] == :none }

          # Go through the params/payload of each action and augment them by
          # adding a generated example (then stick it into the description hash)
          r.actions.each do |action_name, action|
            # skip actions with doc_visibility of :none
            next if action.metadata[:doc_visibility] == :none

            action_description = resource_description[:actions].find {|a| a[:name] == action_name }
          end

          hash[r.id] = resource_description
        end
      end

    end
  end
end

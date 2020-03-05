require_relative 'operation_object.rb'
module Praxis
  module Docs
    module OpenApi
      class PathsObject
        # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#paths-object
        attr_reader :resources, :paths
        def initialize(resources:)
          @resources = resources
          # A hash with keys of paths, and values of hash
          # where the subhash has verb keys and path_items as values
          # {
          #   "/pets": {
          #       "get": {...},
          #       "post": { ...}
          #   "/humans": {
          #       "get": {...},
          @paths = Hash.new {|h,k| h[k] = {} }
        end


        def dump
          resources.each do |id, info|
            compute_resource_paths( id, info)
          end
          paths
        end

        def compute_resource_paths( id, resource )
          # fill in the paths hash with a key for each path for each action/route
          resource[:actions].each do |action|
            action[:urls].each do |url|
              verb = url[:verb].downcase
              templetized_path = OpenApiGenerator.templatize(url[:path])
              path_entry = paths[templetized_path]
              # Let's fill in verb stuff within the working hash
              raise "VERB #{_verb} already defined for #{id}!?!?!" if path_entry[verb]
              
              action_uid = "action-#{action[:name]}-#{id}"
              # Add a tag matching the resource name (hoping all actions of a resource are grouped)
              action_tags = [id]
              path_entry[verb] = OperationObject.new( id: action_uid, url: url, action: action, tags: action_tags).dump
            end
          end
          # For each path, we can further annotate with 
          # servers
          # parameters 
          # But we don't have that concept in praxis
        end
      end
    end
  end
end

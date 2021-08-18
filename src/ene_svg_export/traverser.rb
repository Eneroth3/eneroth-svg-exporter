# frozen_string_literal: true

Sketchup.require "ene_svg_export/instance_path_helper"

module Eneroth
  module SVGExport
    # Functionality for recursively traversing over model hierarchy.
    module Traverser
      # Traverse model hierarchy.
      #
      # @param entities [Sketchup::Entities, Array<Sketchup::DrawingElement>, Sketchup::Selection]
      #
      # @yieldparam instance_path [InstancePath]
      def self.traverse(entities, wysiwyg = true, &block)
        # TODO: Add wysiwyg param.
        # Rely on new InstancePathHelper.resolved_visiblity?
        # Require InstancePathHelper.

        raise ArgumentError, "No block given." unless block_given?
        traverse_with_backtrace(entities, [], wysiwyg, &block)
      end
      
      # Private

      def self.traverse_with_backtrace(entities, backtrace, wysiwyg, &block)
        entities.each do |entity|
          instance_path = Sketchup::InstancePath.new(backtrace.to_a + [entity])
          next unless InstancePathHelper.resolve_visibility?(instance_path)
          
          yield instance_path
          next unless instance?(entity)

          traverse_with_backtrace(entity.definition.entities, instance_path, wysiwyg, &block)
        end
      end
      private_class_method :traverse_with_backtrace

      def self.instance?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end
      private_class_method :instance?
    end
  end
end

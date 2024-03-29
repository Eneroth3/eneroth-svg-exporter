# frozen_string_literal: true

Sketchup.require "ene_svg_exporter/instance_path_helper"

module Eneroth
  module SVGExporter
    # Functionality for recursively traversing over model hierarchy.
    module Traverser
      # Traverse model hierarchy.
      #
      # @param entities [Sketchup::Entities, Array<Sketchup::DrawingElement>, Sketchup::Selection]
      # @param wysiwyg [Boolean] Whether to skip elements that are currently hidden.
      #
      # @yieldparam instance_path [InstancePath]
      def self.traverse(entities, wysiwyg = true, &block)
        raise ArgumentError, "No block given." unless block_given?

        traverse_with_backtrace(entities, [], wysiwyg, &block)
      end

      # Private

      def self.traverse_with_backtrace(entities, backtrace, wysiwyg, &block)
        # TODO: Break out sorting by Z value from general traverse thing to the implementation using it.
        entities.sort_by { |e| e.bounds.min.z }.each do |entity|
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

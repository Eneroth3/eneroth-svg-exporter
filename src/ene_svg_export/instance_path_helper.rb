# frozen_string_literal: true

Sketchup.require "ene_svg_export/traverser"
Sketchup.require "ene_svg_export/instance_path_helper"

module Eneroth
  module SVGExport
    # Functionality related to `Sketchup::InstancePath`.
    module InstancePathHelper
      # Get the display color for a DrawingElement, honoring SketchUp's
      # material inheritance model and default material.
      #
      # @param instance_path [Sketchup::InstancePath]
      #
      # @return [Sketchup::Material, nil]
      def self.resolve_color(instance_path)
        material = resolve_material(instance_path)
        return material.color if material

        Sketchup.active_model.rendering_options["FaceFrontColor"]
      end

      # Get the display material for a DrawingElement, honoring SketchUp's
      # material inheritance model.
      #
      # @param instance_path [Sketchup::InstancePath]
      #
      # @return [Sketchup::Material, nil]
      def self.resolve_material(instance_path)
        instance_path.to_a.reverse.each do |entity|
          return entity.material if entity.material
        end
        
        nil
      end
    end
  end
end

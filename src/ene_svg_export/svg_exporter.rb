# frozen_string_literal: true

Sketchup.require "ene_svg_export/traverser"
Sketchup.require "ene_svg_export/instance_path_helper"

module Eneroth
  module SVGExport
    module SVGExporter
      def self.export
        model = Sketchup.active_model

        bounds = Geom::BoundingBox.new
        model.selection.each { |e| bounds.add(e.bounds) }

        # TODO: Ask scale
        scale = 1

        basename = File.basename(model.path, ".skp")
        basename = "Untitled" if basename.empty? # REVIEW: Want to have the translated name.
        path = UI.savepanel("Export SVG", nil, "#{basename}.svg")
        # REVIEW: Adding extension should ideally be done by underlying method,
        # and honored in file overwrite warning).
        path += ".svg" unless path.end_with?("svg")

        # For once the BoindingBox#height method (Y extents) is what we regard as
        # height, as we are doing a 2D on the XY plane. Wohoo!
        svg = svg_start(bounds.width * scale, bounds.height * scale)

        initial_transformation =
          Geom::Transformation.scaling(ORIGIN, scale) *
          Geom::Transformation.translation(bounds.min).inverse *
          Geom::Transformation.scaling(bounds.center, 1, -1, 1)

        Traverser.traverse(model.selection) do |instance_path|
          entity = instance_path.to_a.last
          next unless entity.is_a?(Sketchup::Face)

          transformation = initial_transformation * instance_path.transformation
          color = InstancePathHelper.resolve_color(instance_path)
          svg += svg_path(entity, transformation, color)
          # TODO: Add edge support?
        end
        svg += svg_end

        File.write(path, svg)
      end

      def self.svg_start(width, height)
        "<svg xmlns=\"http://www.w3.org/2000/svg\""\
        " width=\"#{format_length_with_unit(width)}\""\
        " height=\"#{format_length_with_unit(height)}\""\
        " viewBox=\"0 0 #{format_length(width)} #{format_length(height)}\">\n"
      end

      def self.svg_end
        "</svg>\n"
      end

      def self.svg_path(face, transformation, color)
        d = face.vertices.map do |vertex|
          position = vertex.position.transform(transformation)
          "L #{format_length(position.x)} #{format_length(position.y)}"
        end.join(" ")
        # First "command" should be move to, not line to.
        d[0] = "M"

        "<path d=\"#{d}\" fill=\"#{format_color(color)}\" />\n"
      end

      def self.format_length(length)
        "#{length.to_mm}"
      end

      def self.format_length_with_unit(length)
        "#{format_length(length)}mm"
      end

      def self.format_color(color)
        "#" + color.to_a.map { |c| sprintf("%02x", c) }.join.upcase
      end
    end
  end
end

# frozen_string_literal: true

module Eneroth
  module SVGExport
    module SVGExporter
      def self.export
        model = Sketchup.active_model

        bounds = Geom::BoundingBox.new
        model.selection.each { |e| bounds.add(e.bounds) }

        # TODO: Ask scale

        basename = File.basename(model.path)
        basename = "Untitled" if basename.empty? # REVIEW: Want to have the translated name.
        path = UI.savepanel("Export SVG", nil, "#{basename}.svg")
        # REVIEW: Adding extension should ideally be done by underlying method,
        # and honored in file overwrite warning).
        path += ".svg" unless path.end_with?("svg")

        # For once the BoindingBox#height method (Y extents) is what we regard as
        # height, as we are doing a 2D on the XY plane. Wohoo!
        svg = svg_start(bounds.width, bounds.height)

        initial_transformation =
          Geom::Transformation.translation(bounds.min).inverse *
          Geom::Transformation.scaling(bounds.center, 1, -1, 1)

        traverse(model.selection, initial_transformation) do |entity, transformation|
          next unless entity.is_a?(Sketchup::Face)
          svg += svg_path(entity, transformation)
          # TODO: Add edge support?
        end
        svg += svg_end

        File.write(path, svg)
      end
      
      # TODO: Extract traversing stuff to other file. Yield InstancePath.
      # Have param for wysiwyg.
      # Add helper method for resolving material from InstancePath.
      # Add helper method for resolving color from material or nil.

      # @param entities [Sketchup::Entities, Array<Sketchup::DrawingElement>, Sketchup::Selection]
      #
      # @yieldparam entity [Sketchup::DrawingElement]
      # @yieldparam
      def self.traverse(entities, transformation = IDENTITY, &block)
        entities.each do |entity|
          if entity.is_a? Sketchup::Group || Sketchup::ComponentInstance
            traverse(entity.definition.entities, transformation * entity.transformation, &block)
          else
            block.call(entity, transformation)
          end
        end
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

      def self.svg_path(face, transformation)
        d = face.vertices.map do |vertex|
          position = vertex.position.transform(transformation)
          "L #{format_length(position.x)} #{format_length(position.y)}"
        end.join(" ")
        # First "command" should be move to, not line to.
        d[0] = "M"

        # TODO: Lookup color smarter. Support no material.
        "<path d=\"#{d}\" fill=\"#{format_color(face.material.color)}\" />\n"
      end

      def self.format_length(length)
        "#{length.to_mm}"
      end

      def self.format_length_with_unit(length)
        "#{format_length(length)}mm"
      end

      def self.format_color(color)
        "#" + color.to_a.map { |c| c.to_s(16).upcase }.join
      end
    end
  end
end

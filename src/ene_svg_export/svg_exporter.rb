# frozen_string_literal: true

module Eneroth
  module SVGExport
    module SVGExporter
      def self.export
        model = Sketchup.active_model

        bounds = Geom::BoundingBox.new
        model.selection.each { |e| bounds.add(e.bounds) }

        # TODO: Ask scale
        scale = 1

        basename = File.basename(model.path)
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

        traverse(model.selection) do |instance_path|
          entity = instance_path.to_a.last
          next unless entity.is_a?(Sketchup::Face)

          transformation = initial_transformation * instance_path.transformation
          color = resolve_color(instance_path)
          svg += svg_path(entity, transformation, color)
          # TODO: Add edge support?
        end
        svg += svg_end

        File.write(path, svg)
      end


      # TODO: Break out to Traverser module. Make other methods private.

      # Traverse model hierarchy.
      #
      # @param entities [Sketchup::Entities, Array<Sketchup::DrawingElement>, Sketchup::Selection]
      #
      # @yieldparam instance_path [InstancePath]
      def self.traverse(entities, &block)
        # TODO: Add wysiwyg param. Rely on new resolve_visible?

        raise ArgumentError, "No block given." unless block_given?
        traverse_with_backtrace(entities, [], &block)
      end

      def self.traverse_with_backtrace(entities, backtrace, &block)
        entities.each do |entity|
          yield Sketchup::InstancePath.new(backtrace + [entity])
          next unless instance?(entity)

          traverse_with_backtrace(entity.definition.entities, backtrace + [entity], &block)
        end
      end

      def self.instance?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
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



      # TODO: Break out to InstancePathHelper module.

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
      end
    end
  end
end

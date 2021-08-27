# frozen_string_literal: true

Sketchup.require "ene_svg_exporter/traverser"
Sketchup.require "ene_svg_exporter/instance_path_helper"
Sketchup.require "ene_svg_exporter/vendor/scale"

module Eneroth
  module SVGExporter
    # SVG Exporter
    module Exporter
      @scale ||= Scale.new(1)

      # Export top view of selected entities to a SVG.
      def self.export
        scale = prompt_scale(@scale)
        return unless scale

        @scale = scale

        model = Sketchup.active_model

        path = prompt_path(model, ".svg")
        return unless path

        bounds = Geom::BoundingBox.new
        model.selection.each { |e| bounds.add(e.bounds) }

        # For once the BoindingBox#height method (Y extents) is what we regard as
        # height, as we are doing a 2D view on the horizontal plane. Wohoo!
        svg = svg_start(bounds.width * @scale.factor, bounds.height * @scale.factor)

        initial_transformation =
          Geom::Transformation.scaling(ORIGIN, @scale.factor) *
          Geom::Transformation.translation(bounds.min).inverse *
          Geom::Transformation.scaling(bounds.center, 1, -1, 1)

        svg += svg_content(model.selection, initial_transformation)
        svg += svg_end

        File.write(path, svg)
      end

      # Ask the user for a scale.
      # Shows error message and returns `nil` for invalid input.
      #
      # @param default [Scale]
      #
      # @return [Scale, nil]
      def self.prompt_scale(default)
        results = UI.inputbox(["Scale"], [default.to_s], EXTENSION.name)
        return unless results

        scale = Scale.new(results[0])
        unless scale.valid?
          UI.messagebox("Invalid scale.")
          return
        end

        scale
      end

      # Ask the user for a path.
      # Defaults to the name of the open model and forces a file extension.
      #
      # @param model [Sketchup::Model]
      # @param extension [String] File extension including leading dot.
      #
      # @return [String, nil]
      def self.prompt_path(model, extension)
        basename = File.basename(model.path, ".skp")
        # REVIEW: Want to have the translated name if running localized SU version.
        basename = "Untitled" if basename.empty?
        path = UI.savepanel("Export SVG", nil, "#{basename}#{extension}")
        return unless path

        # REVIEW: Adding extension should ideally be done by underlying method,
        # and honored in file overwrite warning.
        path += extension unless path.end_with?(extension)

        path
      end

      # Generate SVG start.
      #
      # @param width [Length] in model space
      # @param height [Length] in model space
      #
      # @return [String]
      def self.svg_start(width, height)
        "<svg xmlns=\"http://www.w3.org/2000/svg\""\
        " width=\"#{format_length_with_unit(width)}\""\
        " height=\"#{format_length_with_unit(height)}\""\
        " viewBox=\"0 0 #{format_length(width)} #{format_length(height)}\">\n"
      end

      # Generate SVG content/middle.
      #
      # @param entities [Sketchup::Selection, Sketchup::Entities, Array<Sketchup::Drawingelement>]
      # @param initial_transformation [Geom::Transformation] from model space to paper space.
      #
      # @return [String]
      def self.svg_content(entities, initial_transformation)
        svg = ""

        Traverser.traverse(entities) do |instance_path|
          entity = instance_path.to_a.last
          next unless entity.is_a?(Sketchup::Face)

          transformation = initial_transformation * instance_path.transformation
          color = InstancePathHelper.resolve_color(instance_path)
          svg += svg_path(entity, transformation, color)
          # TODO: Add edge support?
        end

        svg
      end

      # Generate SVG end.
      #
      # @return [String]
      def self.svg_end
        "</svg>\n"
      end

      # Generate SVG path.
      #
      # @param face [Sketchup::Face]
      # @param transformation [Geom::Transformation] from local space to paper space.
      # @param color [Sketchup::Color]
      #
      # @return [String]
      def self.svg_path(face, transformation, color)
        d = face.outer_loop.vertices.map do |vertex|
          position = vertex.position.transform(transformation)
          "L #{format_length(position.x)} #{format_length(position.y)}"
        end.join(" ")
        # First "command" should be move to, not line to.
        d[0] = "M"

        # Inner loops, skip loops[0] as it is the outer loop.
        face.loops[1..-1].each do |loop|
          d_inner = loop.vertices.map do |vertex|
            position = vertex.position.transform(transformation)
            "L #{format_length(position.x)} #{format_length(position.y)}"
          end.join(" ")
          d_inner[0] = "M"
          d += d_inner
        end

        "<path d=\"#{d}\" fill=\"#{format_color(color)}\" />\n"
      end

      # Format a length for SVG, without unit.
      #
      # @param length [Length]
      #
      # @return [String]
      def self.format_length(length)
        length.to_mm.to_s
      end

      # Format a length for SVG, with unit.
      #
      # @param length [Length]
      #
      # @return [String]
      def self.format_length_with_unit(length)
        "#{format_length(length)}mm"
      end

      # Format a color for SVG.
      #
      # @param color [Sketchup::Color]
      #
      # @return [String]
      def self.format_color(color)
        "#" + color.to_a.values_at(0..2).map { |c| format("%02x", c) }.join.upcase
      end
    end
  end
end

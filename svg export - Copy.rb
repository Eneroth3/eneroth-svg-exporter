def export
  selection = Sketchup.active_model.selection
  bounds = Geom::BoundingBox.new
  selection.each { |e| bounds.add(e.bounds) }

  # TODO: Ask scale

  path = UI.savepanel("Export SVG", nil, "file.svg") # TODO: Base on model filename.

  # Actually using Y extent as height here, as we are dealing with a 2D export.
  svg = svg_start(bounds.width, bounds.height)
  
  # TODO: Set up initial transformation
  # Any mirroring around any axis?

  traverse(selection) do |entity, transformation|
    next unless entity.is_a?(Sketchup::Face)
    svg += svg_path(entity, transformation)
    # TODO: Add edge support
  end
  svg += svg_end

  File.write(path, svg)
end

# @param entities [Sketchup::Entities, Array<Sketchup::DrawingElement>, Sketchup::Selection]
#
# @yieldparam entity [Sketchup::DrawingElement]
# @yieldparam
def traverse(entities, transformation = IDENTITY, &block)
  entities.each do |entity|
    if entity.is_a? Sketchup::Group || Sketchup::ComponentInstance
      traverse(entity.definition.entities, transformation * entity.transformation, &block)
    else
      block.call(entity, transformation)
    end
  end
end

def svg_start(width, height)
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 #{format_length(width)} #{format_length(height)}\">\n"
end

def svg_end
  "</svg>\n"
end

def svg_path(face, transformation)
  d = face.vertices.map do |vertex|
    position = vertex.position.transform(transformation)
    "L #{format_length(position.x)} #{format_length(position.y)}"
  end.join(" ")
  # First "command" should be move to, not line to.
  d[0] = "M"
  
  # TODO: Lookup color smarter. Support no material.
  "<path d=\"#{d}\" fill=\"#{format_color(face.material.color)}\" />\n"
end

def format_length(length)
  # Using mm for (non-American) human-readable files.
  "#{length.to_mm}mm"
end

def format_color(color)
  "#" + color.to_a.map { |c| c.to_s(16).upcase }.join
end

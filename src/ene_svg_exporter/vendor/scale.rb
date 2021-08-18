# Represents the scale of a view or drawing.
class Eneroth::SVGExporter::Scale
  include Comparable

  # Multiples of 10^N used in common scales.
  # Typical scales used for drawings are 1:1, 1:2, 1:5, 1:10, 1:20, 1:50 etc.
  COMMON_SCALE_FACTORS = [1, 2, 5, 10].freeze

  # Multiples of 10^N used in common and less common scales.
  # The more unorthodox scales, such as 1:30 and 1:800, can be used to fit
  # a drawing better into a layout e.g. in a portfolio.
  EXTENDED_SCALE_FACTORS = [1, 1.5, 2, 3, 4, 5, 8, 10].freeze

  # Get source string scale was created from, or nil if it was created
  # from a number.
  #
  # @return [String, nil]
  attr_reader :source_string

  # Create a Scale object.
  # If not a valid object can be created, the `invalid?` method on the object
  # will return false.
  #
  # @param number_or_string [Numeric, String]
  #
  # @example
  #   Scale.new("1:100")
  #   Scale.new("10%")
  #   Scale.new(0.01)
  #   Scale.new("1\" = 4 m")
  def initialize(number_or_string)
    if number_or_string.is_a?(Numeric)
      @factor = number_or_string
    else
      @factor = parse(number_or_string)
      @source_string = number_or_string
    end
  end

  # Compare Scales.
  #
  # @param other [Scale]
  #
  # @return [-1, 0, 1, nil]
  def <=>(other)
    return unless other.is_a?(self.class)
    return unless other.valid?
    return unless valid?
    return 0 if (@factor - other.factor).abs <= FLOAT_TOLERANCE

    @factor <=> other.factor
  end

  # Create a copy rounded upwards, for a larger drawing.
  #
  # If a scale has been calculated to exactly fit a drawing into a drawing area,
  # this can be used to give the drawing a more reasonable scale while still
  # filling up the full drawing area.
  #
  # @param target [Array<Numeric>] Multiples of 10^N to round to.
  #
  # @return [Scale]
  def ceil(target: COMMON_SCALE_FACTORS)
    dup.ceil!(target: target)
  end

  # Round scale upwards, for a larger drawing.
  #
  # If a scale has been calculated to exactly fit a drawing into a drawing area,
  # this can be used to give the drawing a more reasonable scale while still
  # filling up the full drawing area.
  #
  # @param target [Array<Numeric>] Multiples of 10^N to round to.
  #
  # @return [Scale]
  def ceil!(target: COMMON_SCALE_FACTORS)
    round!(target: target, direction: 1)
  end

  # Get developer friendly string representation of Scale.
  #
  # @return [String]
  def inspect
    return "<#{self.class.name} (Invalid)>" unless valid?

    "<#{self.class.name} #{@factor}>"
  end

  # Get scale factor for Scale.
  #
  # @return [Numeric, nil]
  def factor
    @factor if valid?
  end

  # Create a copy rounded downwards, for a smaller drawing.
  #
  # If a scale has been calculated to exactly fit a drawing into a drawing area,
  # this can be used to give the drawing a more reasonable scale while still
  # being contained within the drawing area.
  #
  # @param target [Array<Numeric>] Multiples of 10^N to round to.
  #
  # @return [Scale]
  def floor(target: COMMON_SCALE_FACTORS)
    dup.floor!(target: target)
  end

  # Round scale downwards, for a smaller drawing.
  #
  # If a scale has been calculated to exactly fit a drawing into a drawing area,
  # this can be used to give the drawing a more reasonable scale while still
  # being contained within the drawing area.
  #
  # @param target [Array<Numeric>] Multiples of 10^N to round to.
  #
  # @return [Scale]
  def floor!(target: COMMON_SCALE_FACTORS)
    round!(target: target, direction: -1)
  end

  # Format human readable string based on scale factor, e.g. "1:100" or "~1:42".
  #
  # @return [String]
  def format
    string =
      if @factor > 1
        "#{@factor.round}:1"
      else
        "1:#{(1 / @factor).round}"
      end
    string = "~#{string}" unless self == self.class.new(string)

    string
  end

  # Create a copy rounded to a commonly used scale.
  #
  # @param target [Array<Numeric>] Multiples of 10^N to round to.
  # @param direction [-1, 0, 1] Round down, to closest or up.
  #
  # @return [Scale]
  def round(target: COMMON_SCALE_FACTORS, direction: 0)
    dup.round!(target: target, direction: direction)
  end

  # Round to a commonly used scale.
  #
  # @param target [Array<Numeric>] Multiples of 10^N to round to.
  # @param direction [-1, 0, 1] Round down, to closest or up.
  #
  # @return [Scale]
  def round!(target: COMMON_SCALE_FACTORS, direction: 0)
    # Scale can no longer be considered to be generated from string.
    @source_string = nil

    # If the scale factor is smaller than 1, round its inverse to an sensible
    # number. In 1:x, x should be the sensible value, not its inverse.
    downsize = @factor < 1
    @factor = 1 / @factor if downsize
    direction = -direction if downsize

    coefficient, exponent = split_number(@factor)
    coefficient = round_to_target(coefficient, target, direction)

    # Sometimes Rational is included and overrides Ruby core math functionality.
    # Ensure result is float to honor API contract and avoid unexpected
    # consequence elsewhere.
    @factor = (coefficient * 10**exponent).to_f

    @factor = 1 / @factor if downsize

    self
  end

  # Get string representation of Scale. If Scale was created from string the
  # same string is returned, otherwise a new string is formatted.
  #
  # @return [String]
  def to_s
    @source_string || format
  end

  # Check if Scale is valid. A Scale is not valid if the scale factor is 0 or
  # undetermined.
  #
  # @return [Boolean]
  def valid?
    !!@factor && !@factor.zero? && @factor.finite?
  end

  private

  # Float tolerance used internally in SketchUp.
  # From testup-2\src\testup\sketchup_test_utilities.rb
  FLOAT_TOLERANCE = 1.0e-10
  private_constant :FLOAT_TOLERANCE

  # Parse factor from string.
  #
  # @param string [String]
  #
  # @return [Float, nil]
  def parse(string)
    string = string.tr(",", ".").delete("~")
    if (match = string.match(/^(\d*\.?\d*)$/))
      match[1].to_f
    elsif (match = string.match(/^(\d*\.?\d*)%$/))
      match[1].to_f / 100
    elsif (match = string.match(/^(\d*\.?\d*)[:\/](\d*\.?\d*)$/))
      match[1].to_f / match[2].to_f
    elsif (match = string.match(/^(.+)\=(.+)$/))
      match[1].strip.to_l / match[2].strip.to_l
    end
  rescue ArgumentError
    # to_l raises when string isn't a valid length.
    nil
  end

  def parse_length(string)
    string.strip.sub("%", "").to_l / (string.end_with?("%") ? 100 : 1)
  rescue ArgumentError
    nil
  end

  # Split number into coefficient and power of 10, e.g. 250 -> 2.55, 2.
  #
  # @param number [Numeric]
  #
  # @return [Array<(Float, Integer)>] Coefficient (`+-[1, 10[`), exponent.
  def split_number(number)
    coefficient, exponent = Kernel.format("%e", number).split("e")

    [coefficient.to_f, exponent.to_i]
  end

  def round_to_target(number, target, direction)
    # REVIEW: What if exactly between two values? Sort and reverse target before
    # comparing?
    case direction
    when 0
      target.min_by { |t| (t - number).abs }
    when -1
      target.select { |t| t <= number }.max
    when 1
      target.select { |t| t >= number }.min
    end
  end
end

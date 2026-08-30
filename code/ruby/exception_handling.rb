# begin/rescue/else/ensure, custom error classes, and retry.

class ValidationError < StandardError
  attr_reader :field

  def initialize(field, message)
    @field = field
    super(message)
  end
end

class OutOfRangeZoneError < ValidationError; end

def parse_zone(raw)
  zone = Integer(raw)
  raise OutOfRangeZoneError.new('zone', "zone #{zone} is outside 1-6") unless (1..6).cover?(zone)

  zone
rescue ArgumentError => e
  # `raise ... from` is implicit in Ruby: the cause is kept automatically.
  raise ValidationError.new('zone', "#{raw.inspect} is not a number")
end

%w[3 9 east].each do |raw|
  puts format('%-6s -> zone %d', raw, parse_zone(raw))
rescue OutOfRangeZoneError => e
  # The most specific rescue has to come first.
  puts format('%-6s -> out of range: %s', raw, e.message)
rescue ValidationError => e
  puts format('%-6s -> %s (caused by %s) on field %s', raw, e.message, e.cause.class, e.field)
end

# else runs when nothing was raised; ensure runs either way.
%w[2 nine].each do |raw|
  begin
    zone = parse_zone(raw)
  rescue ValidationError
    puts "#{raw.ljust(6)} rejected"
  else
    puts "#{raw.ljust(6)} accepted as #{zone}"
  ensure
    # cleanup goes here
  end
end

# Several classes in one rescue.
begin
  raise IOError, 'the disk went away'
rescue Errno::ENOENT, IOError => e
  puts "caught a #{e.class}"
end

# retry re-runs the begin block, which needs a counter to terminate.
attempts = 0
begin
  attempts += 1
  raise 'the upstream gave up' if attempts < 3

  puts "succeeded on attempt #{attempts}"
rescue RuntimeError => e
  puts "  attempt #{attempts} failed: #{e.message}"
  retry if attempts < 3
  raise
end

# ensure runs even when the method returns from the begin block.
def with_cleanup
  open = ['report.csv']
  return 'returned from the body'
ensure
  open.clear
  puts "cleaned up, #{open.size} handles left open"
end
puts with_cleanup

# raise with no arguments inside a rescue re-raises the current error.
def logged
  yield
rescue StandardError => e
  puts "  logging #{e.class}"
  raise
end

begin
  logged { Integer('twelve') }
rescue ArgumentError => e
  puts "still the original: #{e.message}"
end

# StandardError is what a bare rescue catches; Exception is wider and
# catching it hides Interrupt and SignalException too.
puts "bare rescue catches: #{StandardError}"
puts "backtrace depth: #{(ValidationError.new('zone', 'x').backtrace || []).size}"

# method_missing and define_method: answering calls that were never written.
# Powerful, and easy to overuse.

class Configuration
  def initialize(values = {})
    @values = values
  end

  # Called when no real method matches. respond_to_missing? must agree, or
  # respond_to? and method() will lie.
  def method_missing(name, *args)
    key = name.to_s

    if key.end_with?('=')
      @values[key.chomp('=').to_sym] = args.first
    elsif key.end_with?('?')
      !!@values[key.chomp('?').to_sym]
    elsif @values.key?(name)
      @values[name]
    else
      super # raises NoMethodError, with the right message and backtrace
    end
  end

  def respond_to_missing?(name, include_private = false)
    key = name.to_s.chomp('=').chomp('?').to_sym
    @values.key?(key) || name.to_s.end_with?('=') || super
  end

  def to_h = @values.dup
end

config = Configuration.new(host: 'localhost', port: 8080, debug: true)

puts config.host
puts config.port
puts "debug? #{config.debug?}"
config.timeout = 5000
puts config.to_h.inspect

puts "responds to host: #{config.respond_to?(:host)}"
puts "responds to nothing: #{config.respond_to?(:nothing)}"

begin
  config.nothing
rescue NoMethodError => e
  puts "caught: #{e.message.split("\n").first}"
end

# define_method is usually the better tool: the methods really exist, so
# they are visible to respond_to?, documentation, and the debugger.
class Station
  FIELDS = %i[name line zone platforms].freeze

  FIELDS.each do |field|
    define_method(field) { @attributes[field] }
    define_method("#{field}=") { |value| @attributes[field] = value }
    define_method("#{field}?") { !@attributes[field].nil? }
  end

  def initialize(**attributes)
    @attributes = attributes
  end
end

station = Station.new(name: 'Alder Cross', line: 'Amber', zone: 2)
puts station.name
station.platforms = 2
puts "platforms? #{station.platforms?}, zone #{station.zone}"
puts "generated methods: #{(Station.instance_methods(false)).sort.first(6).inspect}"

# send reaches any method, including private ones; public_send does not.
puts station.send(:zone)
puts "method object: #{station.method(:name).arity}"

# A tiny DSL built from instance_eval, which is the usual reason to reach
# for this kind of thing.
class Report
  def self.build(&block) = new.tap { |report| report.instance_eval(&block) }

  def initialize = @lines = []

  def line(text) = @lines << text

  def to_s = @lines.join("\n")
end

puts(Report.build do
  line 'Amber: 24 stations'
  line 'Cobalt: 31 stations'
end)

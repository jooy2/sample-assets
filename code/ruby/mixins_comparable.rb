# Comparable and Enumerable are mixins: define one method, and the module
# supplies the rest.

class Zone
  include Comparable

  attr_reader :level

  def initialize(level)
    raise ArgumentError, "zone #{level} is outside 1-6" unless (1..6).cover?(level)

    @level = level
  end

  # Comparable needs only <=>; it builds <, <=, ==, >, >=, between?, and clamp.
  def <=>(other) = level <=> other.level

  def to_s = "zone #{level}"
end

a = Zone.new(2)
b = Zone.new(5)

puts "#{a} < #{b}: #{a < b}"
puts "equal: #{a == Zone.new(2)}"
puts "between: #{Zone.new(3).between?(a, b)}"
puts "clamped: #{Zone.new(6).clamp(a, b)}"
puts "sorted: #{[b, a, Zone.new(4)].sort.map(&:to_s).inspect}"
puts "max: #{[a, b].max}"

class Route
  include Enumerable

  def initialize(*stops)
    @stops = stops
  end

  # Enumerable needs only #each; it builds map, select, sort, min_by, and
  # about fifty more.
  def each
    return to_enum(:each) unless block_given?

    @stops.each { |stop| yield stop }
  end

  def <<(stop)
    @stops << stop
    self
  end
end

route = Route.new('Alder Cross', 'Quill Wharf') << 'Saltwick Halt'

puts route.map(&:upcase).inspect
puts route.select { |stop| stop.length > 11 }.inspect
puts route.sort.inspect
puts route.min_by(&:length)
puts route.each_with_index.to_a.inspect
puts route.first(2).inspect
puts "count: #{route.count}, includes: #{route.include?('Quill Wharf')}"

# A module can add both instance and class methods through the `included`
# hook, which is how most Ruby libraries do it.
module Trackable
  def self.included(base) = base.extend(ClassMethods)

  module ClassMethods
    def tracked = @tracked ||= []

    def track(instance) = tracked << instance
  end

  def track! = self.class.track(self)
end

class Tram
  include Trackable

  def initialize(name)
    @name = name
    track!
  end

  def to_s = @name
end

Tram.new('Tram 14')
Tram.new('Tram 9')
puts "tracked: #{Tram.tracked.map(&:to_s).inspect}"
puts "ancestors: #{Route.ancestors.take(3).inspect}"

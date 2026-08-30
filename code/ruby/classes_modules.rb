# Classes, modules as namespaces, and the difference between include,
# extend, and prepend.

module Transit
  # A module is a namespace as well as a bag of methods.
  VERSION = '1.0.0'

  module Describable
    def describe = "#{self.class.name.split('::').last}: #{label}"
  end

  module Countable
    # Methods here become class methods when the module is extended.
    def built = @built ||= 0

    def record_build = @built = built + 1
  end

  module Auditing
    # prepend puts the module ahead of the class in the lookup chain, so
    # super reaches the original method.
    def label
      "[audited] #{super}"
    end
  end

  class Vehicle
    include Describable
    extend Countable

    attr_reader :name, :capacity

    def initialize(name, capacity)
      @name = name
      @capacity = capacity
      self.class.record_build
    end

    def label = "#{name} (#{capacity} seats)"

    protected

    def seats = capacity

    private

    def serial = "V-#{object_id}"
  end

  class Tram < Vehicle
    prepend Auditing

    attr_reader :line

    def initialize(name, capacity, line)
      super(name, capacity)
      @line = line
    end

    def label = "#{super} on the #{line} line"

    def bigger_than?(other) = seats > other.seats # protected is visible to siblings
  end
end

tram = Transit::Tram.new('Tram 14', 180, 'Amber')
ferry = Transit::Vehicle.new('Harbour Ferry', 240)

puts tram.describe
puts ferry.describe
puts "version #{Transit::VERSION}, built #{Transit::Vehicle.built}"
puts "the ferry is bigger: #{Transit::Tram.new('Tram 9', 100, 'Slate').bigger_than?(tram) == false}"

puts "send reaches a private method: #{tram.send(:serial).start_with?('V-')}"

begin
  tram.serial
rescue NoMethodError => e
  puts "private: #{e.message.split("\n").first}"
end

puts "ancestors: #{Transit::Tram.ancestors.take(5).inspect}"
puts "is a Vehicle: #{tram.is_a?(Transit::Vehicle)}"
puts "responds to describe: #{tram.respond_to?(:describe)}"
puts "instance methods it defines: #{Transit::Tram.instance_methods(false).sort.inspect}"

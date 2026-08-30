# Writing methods that take a block, and returning an Enumerator when no
# block is given.

class Countdown
  include Enumerable

  def initialize(from)
    @from = from
  end

  # The convention: without a block, hand back an Enumerator so the method
  # composes with map, select, lazy, and the rest.
  def each
    return to_enum(:each) { @from } unless block_given?

    @from.downto(1) { |value| yield value }
  end
end

countdown = Countdown.new(5)
countdown.each { |n| print "#{n} " }
puts
puts countdown.to_a.inspect
puts "size without walking it: #{countdown.each.size}"
puts countdown.map { |n| n * n }.inspect

# yield passes values to the block; the block's value comes back.
def transform_each(values)
  values.map { |value| yield value }
end
puts transform_each([1, 2, 3]) { |n| n * 10 }.inspect

# block_given? lets one method serve both call styles.
def each_zone(range = 1..5)
  return to_enum(:each_zone, range) unless block_given?

  range.each { |zone| yield zone, zone <= 2 ? 'central' : 'outer' }
end

each_zone { |zone, band| puts "  zone #{zone} is #{band}" }
puts each_zone.to_a.first(2).inspect

# An explicit &block can be stored, forwarded, or inspected.
def twice(&block)
  return to_enum(:twice) unless block

  2.times { block.call }
end

count = 0
twice { count += 1 }
puts "ran #{count} times"

# Enumerator.new builds a sequence from scratch, including an endless one.
fibonacci = Enumerator.new do |yielder|
  a, b = 0, 1
  loop do
    yielder << b
    a, b = b, a + b
  end
end
puts fibonacci.take(12).inspect
puts fibonacci.lazy.select(&:even?).first(5).inspect

# External iteration: pull one value at a time.
enumerator = %w[Amber Cobalt Emerald].each
puts enumerator.next
puts enumerator.next
enumerator.rewind
puts "after rewind: #{enumerator.next}"

begin
  3.times { enumerator.next }
rescue StopIteration
  puts 'ran off the end, which is what StopIteration means'
end

# each_with_object and chained enumerators avoid temporary variables.
puts (1..10).each_slice(3).map(&:sum).inspect
puts %w[a b c].each_with_index.map { |letter, index| "#{index}:#{letter}" }.inspect
puts (1..Float::INFINITY).lazy.map { |n| n * n }.first(5).inspect

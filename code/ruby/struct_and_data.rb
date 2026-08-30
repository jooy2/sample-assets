# Struct builds a mutable value class in one line; Data (Ruby 3.2) builds an
# immutable one.

Station = Struct.new(:name, :line, :zone, :platforms, keyword_init: true) do
  def label = "#{name} (zone #{zone})"

  def interchange? = platforms > 3
end

Point = Struct.new(:x, :y) do
  def +(other) = Point.new(x + other.x, y + other.y)

  def to_s = "(#{x}, #{y})"
end

Reading = Data.define(:device, :celsius, :battery) do
  def warning? = celsius > 30 || battery < 15
end

alder = Station.new(name: 'Alder Cross', line: 'Amber', zone: 2, platforms: 2)
quill = Station.new(name: 'Quill Wharf', line: 'Cobalt', zone: 3, platforms: 4)

puts alder.label
puts "interchange: #{quill.interchange?}"

# A Struct is mutable, and can be read positionally or by name.
alder.zone = 3
puts "changed: #{alder.zone}, by index: #{alder[0]}, as a hash: #{alder.to_h}"
puts "members: #{Station.members.inspect}"

# Structs compare and destructure like arrays.
puts "equal: #{Point.new(1, 2) == Point.new(1, 2)}"
puts "sum: #{Point.new(1, 2) + Point.new(3, 4)}"
x, y = *Point.new(45, -10)
puts "destructured: #{x}, #{y}"

# Data is frozen: `with` copies instead of mutating.
reading = Reading.new(device: 'SNS-01', celsius: 21.4, battery: 88)
warmer = reading.with(celsius: 31.2)

puts reading.inspect
puts "warning: #{reading.warning?} -> #{warmer.warning?}"
puts "the original is still #{reading.celsius}"

begin
  reading.instance_variable_set(:@celsius, 0)
rescue FrozenError => e
  puts "frozen: #{e.message}"
end

# Data takes positional or keyword arguments, and rejects unknown members.
puts Reading.new('SNS-07', 19.6, 9).inspect
begin
  Reading.new(device: 'SNS-09')
rescue ArgumentError => e
  puts "missing member: #{e.message}"
end

# Both work as hash keys, because both define #hash and #eql?.
tally = Hash.new(0)
[Point.new(0, 0), Point.new(0, 0), Point.new(1, 1)].each { |p| tally[p] += 1 }
puts tally.inspect

puts "Struct is Enumerable: #{alder.to_a.inspect}"
puts "Data is not mutable, and has no to_a: #{Reading.members.inspect}"

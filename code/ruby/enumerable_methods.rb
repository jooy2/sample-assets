# Enumerable: the module behind map, select, reduce, and the rest. Any class
# with #each and `include Enumerable` gets all of it.

Station = Struct.new(:name, :line, :zone, :platforms, :step_free)

stations = [
  Station.new('Alder Cross',    'Amber',   2, 2, true),
  Station.new('Quill Wharf',    'Cobalt',  3, 4, false),
  Station.new('Saltwick Halt',  'Amber',   5, 1, true),
  Station.new('Nether Gate',    'Emerald', 2, 3, true),
  Station.new('Bramble Fields', 'Cobalt',  4, 2, false)
]

puts stations.select { |s| s.step_free && s.zone <= 3 }.map(&:name).sort.inspect
puts "platforms: #{stations.sum(&:platforms)}"
puts format('average zone: %.2f', stations.sum(&:zone).fdiv(stations.size))

puts stations.group_by(&:line).transform_values { |group| group.map(&:name) }.inspect
puts stations.partition(&:step_free).map(&:size).inspect
puts stations.each_with_object({}) { |s, acc| acc[s.name] = s.zone }.inspect
puts stations.to_h { |s| [s.name, s.zone] }.inspect

puts "deepest: #{stations.max_by(&:zone).name}"
puts "shallowest two: #{stations.min_by(2, &:zone).map(&:name).inspect}"
puts "sorted by two keys: #{stations.sort_by { |s| [s.zone, s.name] }.map(&:name).inspect}"

puts "any in zone 5: #{stations.any? { |s| s.zone == 5 }}"
puts "all have platforms: #{stations.all? { |s| s.platforms.positive? }}"
puts "none on Violet: #{stations.none? { |s| s.line == 'Violet' }}"
puts "exactly one with 4: #{stations.one? { |s| s.platforms == 4 }}"
puts "count on Amber: #{stations.count { |s| s.line == 'Amber' }}"
puts "first deep: #{stations.find { |s| s.zone > 4 }&.name}"

puts "flat words: #{stations.flat_map { |s| s.name.split }.uniq.inspect}"
puts "tally: #{stations.map(&:line).tally.inspect}"
puts "chunked: #{(1..10).each_slice(4).to_a.inspect}"
puts "windowed: #{(1..6).each_cons(3).to_a.inspect}"
puts "zipped: #{%w[a b c].zip([1, 2, 3]).inspect}"
puts "running total: #{[1, 2, 3, 4].each_with_object([]) { |n, acc| acc << (acc.last || 0) + n }.inspect}"

puts "reduce: #{stations.reduce(0) { |sum, s| sum + s.platforms }}"
puts "inject with a symbol: #{[1, 2, 3, 4].inject(:+)}"

# lazy defers the work, so an endless sequence is fine.
puts (1..Float::INFINITY).lazy.map { |n| n * n }.select(&:even?).first(5).inspect

# Building your own Enumerable needs only #each.
class Route
  include Enumerable

  def initialize(*stops) = @stops = stops

  def each(&block) = @stops.each(&block)
end

route = Route.new('Alder Cross', 'Quill Wharf', 'Saltwick Halt')
puts route.map(&:upcase).inspect
puts "sorted: #{route.sort.first}, count: #{route.count}"

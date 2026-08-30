# Hashes: literals, defaults, transformation, and the methods that replace a
# loop.

zones = {
  'Alder Cross' => 2,
  'Quill Wharf' => 3,
  'Saltwick Halt' => 5,
  'Nether Gate' => 2
}

# Symbol keys have their own shorthand, which is what most Ruby code uses.
station = { name: 'Alder Cross', line: 'Amber', zone: 2, step_free: true }

puts station[:name]
puts station.fetch(:line)
puts "missing key: #{station[:platforms].inspect}"
puts "fetch with a default: #{station.fetch(:platforms, 2)}"

begin
  station.fetch(:platforms)
rescue KeyError => e
  puts "fetch without one raises: #{e.message}"
end

# A default block builds the value on the first miss.
counts = Hash.new { |hash, key| hash[key] = 0 }
'mississippi'.each_char { |c| counts[c] += 1 }
puts counts.inspect

grouped = Hash.new { |hash, key| hash[key] = [] }
zones.each { |name, zone| grouped[zone] << name }
puts grouped.inspect

puts zones.select { |_, zone| zone <= 2 }.keys.inspect
puts zones.reject { |_, zone| zone <= 2 }.keys.inspect
puts zones.min_by { |_, zone| zone }.inspect
puts zones.sort_by { |name, zone| [zone, name] }.to_h.inspect
puts zones.sum { |_, zone| zone }

puts zones.transform_values { |zone| zone * 10 }.inspect
puts station.transform_keys(&:to_s).keys.inspect
puts zones.filter_map { |name, zone| name if zone > 2 }.inspect
puts zones.each_with_object([]) { |(name, zone), acc| acc << "#{name}=#{zone}" }.inspect

puts "keys: #{zones.keys.size}, values: #{zones.values.uniq.sort.inspect}"
puts "inverted: #{{ a: 1, b: 2 }.invert.inspect}"
puts "merged: #{station.merge(zone: 4, platforms: 3).inspect}"
puts "merged with a block: #{{ a: 1 }.merge({ a: 2 }) { |_, old, new| old + new }.inspect}"
puts "dug: #{{ station: { location: { x: 45 } } }.dig(:station, :location, :x)}"
puts "sliced: #{station.slice(:name, :zone).inspect}"
puts "without: #{station.except(:step_free).keys.inspect}"

# Any object can be a key, and two equal objects are the same key.
by_pair = { [2, 'Amber'] => 'Alder Cross' }
puts by_pair[[2, 'Amber']]

# Hashes keep insertion order, which is guaranteed in Ruby.
ordered = {}
%w[first second third].each_with_index { |word, index| ordered[word] = index }
puts ordered.keys.inspect

# Keyword arguments are hashes with a nicer call site.
def build(name:, zone: 1, **rest)
  { name:, zone:, extras: rest }
end
puts build(name: 'Vellin Halt', zone: 4, platforms: 3).inspect
puts build(**station.slice(:name, :zone)).inspect

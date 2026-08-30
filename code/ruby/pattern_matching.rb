# Ruby 3 pattern matching: `case/in` destructures as it matches.

readings = [
  { device: 'SNS-01', celsius: -18.4, battery: 74 },
  { device: 'SNS-04', celsius: 31.2, battery: 88 },
  { device: 'SNS-07', celsius: 21.0, battery: 9 },
  { device: 'SNS-09', status: 'offline' }
]

readings.each do |reading|
  message =
    case reading
    in { device: String => id, celsius: Float => c } if c > 30
      "#{id} is too warm at #{c}C"
    in { device: String => id, battery: Integer => b } if b < 15
      "#{id} has #{b}% battery left"
    in { device: String => id, celsius: ..0 }
      "#{id} is below freezing"
    in { device: String => id, status: 'offline' }
      "#{id} is offline"
    in { device: String => id }
      "#{id} is nominal"
    end
  puts message
end

# Array patterns, with a splat for the rest.
case %w[Amber Cobalt Emerald Crimson]
in [first, second, *rest]
  puts "first two: #{first}, #{second}; #{rest.size} more"
end

# Find pattern: locate an element anywhere in the array.
case [1, 4, 'Alder Cross', 9]
in [*, String => name, *]
  puts "found a station name: #{name}"
end

# Alternatives, pinning, and literal matches.
def fare_band(zone)
  case zone
  in 1 | 2 then 'central'
  in 3 | 4 then 'suburban'
  in 5.. then 'outer'
  else 'off the network'
  end
end
puts [1, 3, 5, 0].map { |z| "#{z}: #{fare_band(z)}" }.inspect

expected = 2
case { zone: 2 }
in { zone: ^expected }
  puts "pinned: the zone really is #{expected}"
end

# Deconstruct lets any class join in.
class Station
  attr_reader :name, :line, :zone

  def initialize(name, line, zone)
    @name = name
    @line = line
    @zone = zone
  end

  def deconstruct = [name, line, zone]

  def deconstruct_keys(keys) = { name:, line:, zone: }
end

case Station.new('Alder Cross', 'Amber', 2)
in { name: String => n, zone: 1..3 }
  puts "#{n} is in the inner zones"
end

case Station.new('Saltwick Halt', 'Amber', 5)
in [name, line, zone]
  puts "as an array: #{name} / #{line} / #{zone}"
end

# The one-line forms: => raises when it does not match, in returns a boolean.
{ station: 'Quill Wharf', zone: 3 } => { station:, zone: }
puts "destructured in one line: #{station} in zone #{zone}"
puts "boolean form: #{ { zone: 9 } in { zone: 1..6 } }"

begin
  { zone: 9 } => { zone: 1..6 }
rescue NoMatchingPatternKeyError, NoMatchingPatternError => e
  puts "no match: #{e.class}"
end

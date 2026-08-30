# Symbols, object identity, freezing, and mutation. The parts of Ruby that
# surprise people coming from other languages.

# Two equal strings are two objects; two equal symbols are one.
puts "strings: #{'amber'.object_id == 'amber'.object_id}"
puts "symbols: #{:amber.object_id == :amber.object_id}"
puts "converted: #{:amber.to_s} / #{'amber'.to_sym.inspect}"

# Symbols are the usual choice for keys, names, and states.
state = :pending
puts(case state
     when :open then 'waiting for an agent'
     when :pending then 'waiting on the customer'
     else 'closed'
     end)

# Assignment copies the reference, not the object.
original = +'Alder Cross'
alias_of = original
copy = original.dup

alias_of << ' Station'
puts "original changed with the alias: #{original}"
copy << ' (untouched)'
puts "the dup is separate: #{copy} / #{original}"

# freeze makes an object immutable; dup returns an unfrozen copy, clone
# keeps the frozen state.
frozen = 'Quill Wharf'.freeze
puts "frozen? #{frozen.frozen?}, dup #{frozen.dup.frozen?}, clone #{frozen.clone.frozen?}"

begin
  frozen << '!'
rescue FrozenError => e
  puts "rejected: #{e.message}"
end

# Freezing is shallow: the array is frozen, the strings inside are not.
lines = [+'Amber', +'Cobalt'].freeze
lines.first << ' line'
puts "shallow freeze: #{lines.inspect}"

begin
  lines << 'Emerald'
rescue FrozenError
  puts 'the array itself cannot grow'
end

deep = [+'Amber', +'Cobalt'].map(&:freeze).freeze
begin
  deep.first << '!'
rescue FrozenError
  puts 'a deep freeze needs every element frozen too'
end

# Integers, symbols, nil, true, and false are always frozen.
puts [1.frozen?, :amber.frozen?, nil.frozen?, true.frozen?, 1.5.frozen?].inspect

# Constants are not frozen either: only the name is constant.
COLOURS = %w[amber cobalt].freeze
puts "constant: #{COLOURS.frozen?}"

# equal? is identity, == is value, eql? is value and type.
puts "1 == 1.0: #{1 == 1.0}, 1.eql?(1.0): #{1.eql?(1.0)}, equal?: #{1.equal?(1)}"

# A frozen string literal comment at the top of a file freezes every literal
# in it, which is why so many files start with one.
puts "this file does not use the magic comment, so: #{'x'.frozen?}"

# Symbols are never garbage collected before Ruby 2.2; dynamic ones are now
# safe, but interning arbitrary input is still a habit worth avoiding.
puts "dynamic symbol: #{"zone_#{2}".to_sym.inspect}"

# Strings: interpolation, the methods worth knowing, and mutation.

line = 'Alder Cross,Amber,2,true'
name = 'Quill Wharf'

puts "interpolated: #{name} has #{name.split.size} words"
puts "length #{line.length}, bytes #{line.bytesize}"
puts line.upcase
puts 'quill moor station'.split.map(&:capitalize).join(' ')

puts "includes Amber: #{line.include?('Amber')}"
puts "starts with: #{line.start_with?('Alder')}, ends with: #{line.end_with?('true')}"
puts "index of comma: #{line.index(',')}"

fields = line.split(',')
puts "#{fields.size} fields, last is #{fields.last}"
puts fields.first(3).join(' | ')

puts line.tr(',', ';')
puts line.sub('Amber', 'Cobalt')
puts line.gsub(/,/, ' / ')
puts line.delete('aeiou')
puts line.squeeze('s')

puts "padded: |#{'left'.ljust(12)}|#{'right'.rjust(12)}|#{'mid'.center(11, '.')}|"
puts "trimmed: [#{'   spaced out   '.strip}]"
puts "sliced: #{line[0, 11]} / #{line[-4..]} / #{line[/[A-Z]\w+/]}"

puts format('%-14s %5.2f %03d', 'Alder Cross', 3.4, 2)
puts '%s is in zone %d' % [name, 3]

# Heredocs: <<~ strips the leading indentation, <<~'X' skips interpolation.
zone = 2
puts(<<~REPORT)
  Station: #{name}
  Zone:    #{zone}
REPORT

# Strings are mutable unless frozen; << changes in place, + makes a copy.
buffer = +'zone '
5.times { |n| buffer << (n + 1).to_s << ' ' }
puts buffer.strip

frozen = 'literal'.freeze
begin
  frozen << '!'
rescue FrozenError => e
  puts "frozen: #{e.message}"
end

# Multibyte strings count characters, not bytes.
unicode = 'café naïve'
puts "characters #{unicode.length}, bytes #{unicode.bytesize}"
puts unicode.chars.first(4).join
puts unicode.unicode_normalize(:nfd).length

puts 'each_char: ' + 'amber'.each_char.to_a.inspect
puts 'scan: ' + line.scan(/[A-Z]\w+/).inspect
puts 'succ: ' + 'ST-001'.succ
puts 'reverse: ' + name.reverse
puts 'slug: ' + line.downcase.gsub(/[^a-z0-9]+/, '-').delete_prefix('-').delete_suffix('-')

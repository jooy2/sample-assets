# Reading and writing files: the whole-file helpers, the block form that
# closes for you, and CSV.

require 'csv'
require 'tmpdir'

Dir.mktmpdir('sample-assets-') do |directory|
  path = File.join(directory, 'stations.csv')

  rows = [
    %w[station line zone],
    ['Alder Cross', 'Amber', 2],
    ['Quill Wharf', 'Cobalt', 3],
    ['Saltwick Halt', 'Amber', 5],
    ['Nether Gate', 'Emerald', 2]
  ]

  # The block form closes the handle even if the body raises.
  File.open(path, 'w') do |file|
    rows.each { |row| file.puts(row.join(',')) }
  end

  puts "wrote #{File.size(path)} bytes to #{File.basename(path)}"

  # Whole-file helpers, for anything small.
  puts "first line: #{File.readlines(path, chomp: true).first}"
  puts "lines: #{File.read(path).lines.size}"

  # Reading line by line keeps memory flat however large the file is.
  zones = []
  File.foreach(path).with_index do |line, index|
    next if index.zero?

    name, line_name, zone = line.chomp.split(',')
    zones << zone.to_i
    puts "  Amber: #{name}" if line_name == 'Amber'
  end
  puts format('average zone %.2f', zones.sum.fdiv(zones.size))

  # CSV handles quoting, headers, and type conversion.
  CSV.foreach(path, headers: true, converters: :numeric) do |row|
    puts "  #{row['station']} is in zone #{row['zone']} (#{row['zone'].class})" if row['zone'] > 4
  end

  table = CSV.read(path, headers: true)
  puts "headers: #{table.headers.inspect}, rows: #{table.size}"

  CSV.open(File.join(directory, 'out.csv'), 'w') do |csv|
    csv << %w[station zone]
    csv << ['Vellin Halt, Platform 2', 4] # the comma is quoted for you
  end
  puts "quoted: #{File.read(File.join(directory, 'out.csv')).lines.last.chomp}"

  # Appending, and writing in one call.
  File.write(path, "Vellin Halt,Slate,4\n", mode: 'a')
  puts "now #{File.readlines(path).size} lines"

  # Paths, metadata, and directory listings.
  puts "basename #{File.basename(path)}, extension #{File.extname(path)}"
  puts "directory: #{Dir.children(directory).sort.inspect}"
  puts "glob: #{Dir.glob('*.csv', base: directory).sort.inspect}"
  puts "readable: #{File.readable?(path)}, size #{File.size(path)}"

  # Failures raise, so check first or rescue.
  begin
    File.read(File.join(directory, 'missing.csv'))
  rescue Errno::ENOENT => e
    puts "caught: #{e.class}"
  end

  # Binary mode reads bytes rather than characters.
  puts "first 11 bytes: #{File.binread(path, 11).inspect}"
end

puts 'the temporary directory is gone'

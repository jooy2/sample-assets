# Blocks, procs, and lambdas: three ways to pass code around, and the two
# ways they differ.

# A block is passed to a method and run with yield.
def each_zone
  return to_enum(:each_zone) unless block_given?

  (1..5).each { |zone| yield zone }
end

puts each_zone.to_a.inspect
each_zone { |zone| print "zone #{zone} " }
puts

# &block captures the block as a Proc, so it can be stored or forwarded.
def twice(&block)
  block.call
  block.call
end

count = 0
twice { count += 1 }
puts "ran #{count} times"

# proc and lambda differ in two ways.
strict = ->(a, b) { "lambda got #{a} and #{b}" }
loose  = proc { |a, b| "proc got #{a.inspect} and #{b.inspect}" }

puts strict.call(1, 2)
puts loose.call(1)            # missing arguments become nil
puts loose.call(1, 2, 3)      # extra arguments are dropped

begin
  strict.call(1)
rescue ArgumentError => e
  puts "lambda is strict: #{e.message}"
end

# `return` inside a lambda returns from the lambda; inside a proc it
# returns from the enclosing method.
def with_lambda
  ->() { return :from_the_lambda }.call
  :from_the_method
end

def with_proc
  proc { return :from_the_proc }.call
  :never_reached
end

puts "lambda: #{with_lambda}, proc: #{with_proc}"

# Several ways to call the same thing.
double = ->(n) { n * 2 }
puts [double.call(5), double.(5), double[5], double === 5].inspect

# Symbol#to_proc turns a method name into a block.
puts %w[amber cobalt emerald].map(&:upcase).inspect

# Method objects can be passed around like procs.
formatter = method(:format)
puts formatter.call("%-10s zone %d", "Alder Cross", 2)

# Currying builds a smaller function from a larger one.
fare = ->(base, per_zone, zones) { base + per_zone * zones }
standard = fare.curry[2.40][0.85]
puts format("three zones cost %.2f", standard[3])

# A closure keeps the scope it was made in.
def counter(start = 0)
  value = start
  -> { value += 1 }
end

ticket = counter(1000)
puts [ticket.call, ticket.call, ticket.call].inspect
puts "arity: lambda #{strict.arity}, proc #{loose.arity}, splat #{->(*a) { a }.arity}"

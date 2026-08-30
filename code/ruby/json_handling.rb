# Generating and parsing JSON, and teaching a class how to serialise itself.

require 'json'
require 'date'

class Order
  attr_reader :order_id, :user_id, :total, :status, :shipped_at

  def initialize(order_id:, user_id:, total:, status:, shipped_at: nil)
    @order_id = order_id
    @user_id = user_id
    @total = total
    @status = status
    @shipped_at = shipped_at
  end

  def self.from_hash(hash)
    new(
      order_id: hash['order_id'],
      user_id: hash['user_id'],
      total: hash['total'],
      status: hash['status'],
      shipped_at: hash['shipped_at'] && DateTime.parse(hash['shipped_at'])
    )
  end

  # to_json is what JSON.generate calls; to_h keeps it readable.
  def to_h
    {
      order_id:, user_id:, total:, status:,
      shipped_at: shipped_at&.iso8601
    }.compact
  end

  def to_json(*args) = to_h.to_json(*args)
end

orders = [
  Order.new(order_id: 'ORD-10001', user_id: 82, total: 104.35, status: 'delivered',
            shipped_at: DateTime.new(2025, 11, 3, 9, 15, 0)),
  Order.new(order_id: 'ORD-10002', user_id: 6, total: 42.99, status: 'pending')
]

json = JSON.pretty_generate(orders)
puts json

# Parsing gives string keys by default, symbols with symbolize_names.
parsed = JSON.parse(json)
puts "\nparsed #{parsed.size} orders, first is #{parsed.first['order_id']}"
puts "as symbols: #{JSON.parse(json, symbolize_names: true).first[:status]}"

rebuilt = parsed.map { |hash| Order.from_hash(hash) }
puts "shipped_at is a DateTime again: #{rebuilt.first.shipped_at.is_a?(DateTime)}"
puts format('total %.2f', parsed.sum { |order| order['total'] })

# Compact output, and generating from any object that answers to_h.
puts JSON.generate({ b: 2, a: 1 })
puts({ station: 'Alder Cross', zone: 2 }.to_json)

# JSON Lines: one object per line, so a huge file streams.
lines = (1..3).map { |id| JSON.generate(reading_id: id, celsius: 20 + id / 10.0) }
puts "\njsonl:"
lines.each do |line|
  record = JSON.parse(line)
  puts "  #{record['reading_id']}: #{record['celsius']}C"
end

# Errors carry the position, which is what makes them useful.
begin
  JSON.parse('{"unterminated": ')
rescue JSON::ParserError => e
  puts "\ncaught: #{e.message.lines.first.strip}"
end

# What survives a round trip, and what changes on the way.
original = { symbol_key: :symbol_value, time: nil, nested: { list: [1, 2] } }
puts "round trip: #{JSON.parse(original.to_json).inspect}"

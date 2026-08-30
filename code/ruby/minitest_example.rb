# Minitest ships with Ruby. Run it with `ruby minitest_example.rb`.

require 'minitest/autorun'

# --- the code under test, kept here so the sample stands alone -------------

def fizzbuzz(number)
  return 'FizzBuzz' if (number % 15).zero?
  return 'Fizz' if (number % 3).zero?
  return 'Buzz' if (number % 5).zero?

  number.to_s
end

class Basket
  def initialize = @items = Hash.new(0)

  def add(sku, cents, quantity: 1)
    raise ArgumentError, 'quantity must be at least 1' if quantity < 1

    @items[sku] += cents * quantity
    self
  end

  def total = @items.values.sum

  def checkout(gateway) = gateway.charge(total)
end

# --- the tests -------------------------------------------------------------

class FizzBuzzTest < Minitest::Test
  def test_plain_numbers
    assert_equal '1', fizzbuzz(1)
    assert_equal '22', fizzbuzz(22)
  end

  def test_a_table_of_cases
    { 9 => 'Fizz', 20 => 'Buzz', 45 => 'FizzBuzz', 0 => 'FizzBuzz' }.each do |input, expected|
      assert_equal expected, fizzbuzz(input), "fizzbuzz(#{input})"
    end
  end
end

class BasketTest < Minitest::Test
  def setup
    @basket = Basket.new.add('KIT-0001', 1250)
  end

  def test_total_adds_up
    @basket.add('OUT-0002', 3200, quantity: 2)
    assert_equal 1250 + 6400, @basket.total
  end

  def test_rejects_a_zero_quantity
    error = assert_raises(ArgumentError) { @basket.add('KIT-0001', 100, quantity: 0) }
    assert_match(/at least 1/, error.message)
  end

  def test_checkout_calls_the_gateway
    gateway = Minitest::Mock.new
    gateway.expect(:charge, 'receipt-4821', [1250])

    assert_equal 'receipt-4821', @basket.checkout(gateway)
    gateway.verify
  end

  def test_the_other_assertions
    assert @basket.total.positive?
    refute_nil @basket
    assert_nil @basket.instance_variable_get(:@coupon)
    assert_in_delta 12.50, @basket.total / 100.0, 0.001
    assert_includes [1250, 0], @basket.total
    assert_instance_of Basket, @basket
    assert_respond_to @basket, :checkout
  end

  def teardown
    @basket = nil
  end
end

# The spec style is the same library with a different surface.
describe 'fizzbuzz' do
  it 'names the multiples of three' do
    _(fizzbuzz(9)).must_equal 'Fizz'
  end

  it 'leaves everything else alone' do
    _(fizzbuzz(7)).must_equal '7'
  end
end

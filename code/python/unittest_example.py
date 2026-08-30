"""unittest: fixtures, assertions, subtests, and mocking. Run it with
`python unittest_example.py` or `python -m unittest unittest_example`."""

import unittest
from unittest.mock import MagicMock, patch


# --- the code under test, kept here so the sample stands alone -------------


def fizzbuzz(n: int) -> str:
    if n % 15 == 0:
        return "FizzBuzz"
    if n % 3 == 0:
        return "Fizz"
    if n % 5 == 0:
        return "Buzz"
    return str(n)


class Basket:
    def __init__(self) -> None:
        self._items: dict[str, int] = {}

    def add(self, sku: str, cents: int, quantity: int = 1) -> None:
        if quantity < 1:
            raise ValueError("quantity must be at least 1")
        self._items[sku] = self._items.get(sku, 0) + cents * quantity

    def total(self) -> int:
        return sum(self._items.values())

    def checkout(self, gateway) -> str:
        return gateway.charge(self.total())


# --- the tests -------------------------------------------------------------


class FizzBuzzTests(unittest.TestCase):
    def test_plain_numbers(self) -> None:
        self.assertEqual(fizzbuzz(1), "1")
        self.assertEqual(fizzbuzz(22), "22")

    def test_table_of_cases(self) -> None:
        cases = [(9, "Fizz"), (20, "Buzz"), (45, "FizzBuzz"), (0, "FizzBuzz")]
        for value, expected in cases:
            # subTest reports every failing row, not just the first.
            with self.subTest(value=value):
                self.assertEqual(fizzbuzz(value), expected)


class BasketTests(unittest.TestCase):
    def setUp(self) -> None:
        """Runs before every test in this class."""
        self.basket = Basket()
        self.basket.add("KIT-0001", 1250)

    def tearDown(self) -> None:
        self.basket = Basket()

    def test_total_adds_up(self) -> None:
        self.basket.add("OUT-0002", 3200, quantity=2)
        self.assertEqual(self.basket.total(), 1250 + 6400)

    def test_rejects_a_zero_quantity(self) -> None:
        with self.assertRaises(ValueError) as caught:
            self.basket.add("KIT-0001", 100, quantity=0)
        self.assertIn("at least 1", str(caught.exception))

    def test_checkout_calls_the_gateway(self) -> None:
        gateway = MagicMock()
        gateway.charge.return_value = "receipt-4821"

        receipt = self.basket.checkout(gateway)

        self.assertEqual(receipt, "receipt-4821")
        gateway.charge.assert_called_once_with(1250)

    @patch("builtins.print")
    def test_patching_a_global(self, mocked_print: MagicMock) -> None:
        print("this does not reach the terminal")
        mocked_print.assert_called_once()

    @unittest.skipIf(not hasattr(Basket, "discount"), "discounts are not implemented yet")
    def test_discount(self) -> None:
        self.fail("never runs")

    def test_the_other_assertions(self) -> None:
        self.assertTrue(self.basket.total() > 0)
        self.assertIsNone(getattr(self.basket, "coupon", None))
        self.assertAlmostEqual(self.basket.total() / 100, 12.50, places=2)
        self.assertCountEqual([2, 1, 3], [3, 2, 1])
        self.assertRegex("ORD-10001", r"^ORD-\d{5}$")


if __name__ == "__main__":
    unittest.main(verbosity=2)

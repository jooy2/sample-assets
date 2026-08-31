// inventory_system.cpp — a stores system, written to exercise modern C++.
//
// Concepts and constrained templates, a strong-typedef quantity with
// compile-time units, std::variant for a closed set of stock events, ranges
// and views for the reporting, a small RAII transaction that rolls back on an
// exception, and three-way comparison.
//
//   c++ -std=c++20 -Wall -Wextra -O2 -o inventory inventory_system.cpp
//   ./inventory
//
// One translation unit, standard library only. Every part, supplier, and
// figure below is invented.

#include <algorithm>
#include <chrono>
#include <compare>
#include <concepts>
#include <cstdint>
#include <format>
#include <functional>
#include <iomanip>
#include <iostream>
#include <map>
#include <numeric>
#include <optional>
#include <ranges>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <variant>
#include <vector>

namespace stores {

// --------------------------------------------------------------- quantities

/// A tag type per unit, so a count of metres cannot be added to a count of
/// litres and the compiler will say so.
struct Each   { static constexpr std::string_view symbol = "ea"; };
struct Metre  { static constexpr std::string_view symbol = "m";  };
struct Litre  { static constexpr std::string_view symbol = "L";  };

template <typename T>
concept Unit = requires {
    { T::symbol } -> std::convertible_to<std::string_view>;
};

/// A quantity carrying its unit in the type. Arithmetic only combines
/// quantities of the same unit.
template <Unit U>
class Quantity {
public:
    constexpr Quantity() = default;
    constexpr explicit Quantity(double amount) : amount_(amount) {}

    constexpr double amount() const noexcept { return amount_; }

    constexpr Quantity& operator+=(Quantity other) noexcept {
        amount_ += other.amount_;
        return *this;
    }
    constexpr Quantity& operator-=(Quantity other) noexcept {
        amount_ -= other.amount_;
        return *this;
    }

    friend constexpr Quantity operator+(Quantity a, Quantity b) noexcept {
        return Quantity{a.amount_ + b.amount_};
    }
    friend constexpr Quantity operator-(Quantity a, Quantity b) noexcept {
        return Quantity{a.amount_ - b.amount_};
    }
    friend constexpr Quantity operator*(Quantity a, double scale) noexcept {
        return Quantity{a.amount_ * scale};
    }

    // Defaulted three-way comparison gives <, <=, >, >=, ==, and != at once.
    friend constexpr auto operator<=>(Quantity, Quantity) = default;
    friend constexpr bool operator==(Quantity, Quantity) = default;

    std::string str() const {
        return std::format("{:.2f} {}", amount_, U::symbol);
    }

private:
    double amount_{0};
};

using Count  = Quantity<Each>;
using Length = Quantity<Metre>;
using Volume = Quantity<Litre>;

/// Money in whole pence, so nothing is lost to binary fractions.
class Money {
public:
    constexpr Money() = default;
    constexpr explicit Money(std::int64_t pence) : pence_(pence) {}

    static constexpr Money fromPounds(double pounds) {
        return Money{static_cast<std::int64_t>(pounds * 100 + (pounds < 0 ? -0.5 : 0.5))};
    }

    constexpr std::int64_t pence() const noexcept { return pence_; }

    constexpr Money& operator+=(Money other) noexcept {
        pence_ += other.pence_;
        return *this;
    }
    friend constexpr Money operator+(Money a, Money b) noexcept {
        return Money{a.pence_ + b.pence_};
    }
    friend constexpr Money operator-(Money a, Money b) noexcept {
        return Money{a.pence_ - b.pence_};
    }
    friend constexpr Money operator*(Money a, double quantity) noexcept {
        return Money{static_cast<std::int64_t>(
            static_cast<double>(a.pence_) * quantity + 0.5)};
    }
    friend constexpr auto operator<=>(Money, Money) = default;
    friend constexpr bool operator==(Money, Money) = default;

    std::string str() const {
        const bool negative = pence_ < 0;
        const std::int64_t absolute = negative ? -pence_ : pence_;
        return std::format("{}£{}.{:02}", negative ? "-" : "",
                           absolute / 100, absolute % 100);
    }

private:
    std::int64_t pence_{0};
};

// ------------------------------------------------------------------- items

enum class Category { Deck, Safety, Maintenance, Engineering };

constexpr std::string_view name(Category category) {
    switch (category) {
    case Category::Deck:        return "Deck";
    case Category::Safety:      return "Safety";
    case Category::Maintenance: return "Maintenance";
    case Category::Engineering: return "Engineering";
    }
    return "?";
}

struct Item {
    std::string sku;
    std::string description;
    Category    category{Category::Deck};
    Count       onHand{};
    Count       reorderAt{};
    Money       unitCost{};
    std::string supplier;

    Money value() const { return unitCost * onHand.amount(); }
    bool  belowReorder() const { return onHand < reorderAt; }
};

// ------------------------------------------------------------------ events

/// Every way stock moves, as one closed set. A variant rather than a class
/// hierarchy: the set is fixed, and std::visit then makes exhaustiveness the
/// compiler's problem.
struct Receipt   { std::string sku; Count quantity; Money unitCost; std::string reference; };
struct Issue     { std::string sku; Count quantity; std::string toVessel; };
struct Adjust    { std::string sku; Count delta;    std::string reason; };
struct Writeoff  { std::string sku; Count quantity; std::string reason; };

using Event = std::variant<Receipt, Issue, Adjust, Writeoff>;

std::string describe(const Event& event) {
    return std::visit([](const auto& e) -> std::string {
        using T = std::decay_t<decltype(e)>;
        if constexpr (std::same_as<T, Receipt>) {
            return std::format("receive {:>8} of {} at {} ({})",
                               e.quantity.str(), e.sku, e.unitCost.str(), e.reference);
        } else if constexpr (std::same_as<T, Issue>) {
            return std::format("issue   {:>8} of {} to {}",
                               e.quantity.str(), e.sku, e.toVessel);
        } else if constexpr (std::same_as<T, Adjust>) {
            return std::format("adjust  {:>8} of {} ({})",
                               e.delta.str(), e.sku, e.reason);
        } else {
            return std::format("writeoff{:>8} of {} ({})",
                               e.quantity.str(), e.sku, e.reason);
        }
    }, event);
}

std::string_view skuOf(const Event& event) {
    return std::visit([](const auto& e) -> std::string_view { return e.sku; }, event);
}

// ------------------------------------------------------------------ errors

class StoresError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class UnknownItem : public StoresError {
public:
    explicit UnknownItem(std::string_view sku)
        : StoresError(std::format("no such item: {}", sku)) {}
};

class InsufficientStock : public StoresError {
public:
    InsufficientStock(std::string_view sku, Count wanted, Count held)
        : StoresError(std::format("{}: wanted {}, only {} on hand",
                                  sku, wanted.str(), held.str())) {}
};

// --------------------------------------------------------------- the store

class Store {
public:
    void add(Item item) {
        const std::string sku = item.sku;
        if (!items_.emplace(sku, std::move(item)).second) {
            throw StoresError(std::format("duplicate sku: {}", sku));
        }
        order_.push_back(sku);
    }

    Item& at(std::string_view sku) {
        const auto found = items_.find(std::string{sku});
        if (found == items_.end()) throw UnknownItem(sku);
        return found->second;
    }

    const Item& at(std::string_view sku) const {
        const auto found = items_.find(std::string{sku});
        if (found == items_.end()) throw UnknownItem(sku);
        return found->second;
    }

    /// Items in the order they were added, as a view rather than a copy.
    auto all() const {
        return order_ | std::views::transform(
            [this](const std::string& sku) -> const Item& {
                return items_.at(sku);
            });
    }

    /// Apply one event. Throws rather than allowing stock to go negative.
    void apply(const Event& event) {
        std::visit([this](const auto& e) {
            using T = std::decay_t<decltype(e)>;
            Item& item = at(e.sku);

            if constexpr (std::same_as<T, Receipt>) {
                // A receipt at a new price moves the weighted average cost.
                const double existing = item.onHand.amount();
                const double arriving = e.quantity.amount();
                if (existing + arriving > 0) {
                    const std::int64_t total =
                        static_cast<std::int64_t>(
                            static_cast<double>(item.unitCost.pence()) * existing
                            + static_cast<double>(e.unitCost.pence()) * arriving);
                    item.unitCost = Money{static_cast<std::int64_t>(
                        static_cast<double>(total) / (existing + arriving) + 0.5)};
                }
                item.onHand += e.quantity;

            } else if constexpr (std::same_as<T, Issue>
                                 || std::same_as<T, Writeoff>) {
                if (item.onHand < e.quantity) {
                    throw InsufficientStock(e.sku, e.quantity, item.onHand);
                }
                item.onHand -= e.quantity;

            } else {
                const Count next = item.onHand + e.delta;
                if (next < Count{0}) {
                    throw InsufficientStock(e.sku, Count{-e.delta.amount()},
                                            item.onHand);
                }
                item.onHand = next;
            }
        }, event);

        journal_.push_back(event);
    }

    const std::vector<Event>& journal() const noexcept { return journal_; }

    Money totalValue() const {
        Money total;
        for (const Item& item : all()) total += item.value();
        return total;
    }

private:
    std::unordered_map<std::string, Item> items_;
    std::vector<std::string>              order_;
    std::vector<Event>                    journal_;
};

// ------------------------------------------------------------ transactions

/**
 * All-or-nothing application of several events.
 *
 * The destructor rolls the store back unless commit() ran, which makes the
 * rollback happen on an exception without a catch block anywhere.
 */
class Transaction {
public:
    explicit Transaction(Store& store)
        : store_(store), snapshot_(store) {}

    Transaction(const Transaction&) = delete;
    Transaction& operator=(const Transaction&) = delete;

    ~Transaction() {
        if (!committed_) store_ = std::move(snapshot_);
    }

    void apply(const Event& event) { store_.apply(event); }

    void commit() noexcept { committed_ = true; }

private:
    Store& store_;
    Store  snapshot_;
    bool   committed_{false};
};

// ---------------------------------------------------------------- reporting

/// Anything that can be turned into a row of cells for the table writer.
template <typename T>
concept Row = requires(const T& value) {
    { value.cells() } -> std::convertible_to<std::vector<std::string>>;
};

/// How many columns a UTF-8 string occupies. Counting bytes instead is the
/// usual cause of a table that looks aligned until the first pound sign:
/// "£34.50" is seven bytes and six columns.
std::size_t displayWidth(std::string_view text) {
    std::size_t width = 0;
    for (unsigned char byte : text) {
        if ((byte & 0xC0) != 0x80) ++width;   // count lead bytes only
    }
    return width;
}

/// Print a table, sizing every column to its widest cell.
void writeTable(std::span<const std::string> headings,
                const std::vector<std::vector<std::string>>& rows,
                std::span<const bool> rightAlign = {}) {
    std::vector<std::size_t> widths;
    widths.reserve(headings.size());
    for (const auto& heading : headings) widths.push_back(displayWidth(heading));

    for (const auto& row : rows) {
        for (std::size_t i = 0; i < row.size() && i < widths.size(); ++i) {
            widths[i] = std::max(widths[i], displayWidth(row[i]));
        }
    }

    const auto line = [&](std::span<const std::string> cells) {
        std::string out;
        for (std::size_t i = 0; i < cells.size() && i < widths.size(); ++i) {
            const bool right = i < rightAlign.size() && rightAlign[i];
            const std::size_t shown = displayWidth(cells[i]);
            const std::size_t pad = widths[i] - std::min(widths[i], shown);
            if (right) out += std::string(pad, ' ') + cells[i];
            else       out += cells[i] + std::string(pad, ' ');
            if (i + 1 < widths.size()) out += "  ";
        }
        // Trailing spaces help nobody.
        while (!out.empty() && out.back() == ' ') out.pop_back();
        return out;
    };

    std::cout << "  " << line(headings) << '\n';

    std::string rule;
    for (std::size_t i = 0; i < widths.size(); ++i) {
        rule += std::string(widths[i], '-');
        if (i + 1 < widths.size()) rule += "  ";
    }
    std::cout << "  " << rule << '\n';

    for (const auto& row : rows) std::cout << "  " << line(row) << '\n';
}

void stockReport(const Store& store) {
    static const std::string headings[] = {
        "SKU", "Description", "Category", "On hand", "Reorder", "Unit", "Value", "!"
    };
    static const bool align[] = {false, false, false, true, true, true, true, false};

    std::vector<std::vector<std::string>> rows;
    for (const Item& item : store.all()) {
        rows.push_back({
            item.sku,
            item.description,
            std::string{name(item.category)},
            item.onHand.str(),
            item.reorderAt.str(),
            item.unitCost.str(),
            item.value().str(),
            item.belowReorder() ? "*" : "",
        });
    }
    writeTable(headings, rows, align);
}

void categoryReport(const Store& store) {
    std::map<Category, std::pair<int, Money>> totals;
    for (const Item& item : store.all()) {
        auto& [count, value] = totals[item.category];
        ++count;
        value += item.value();
    }

    static const std::string headings[] = {"Category", "Lines", "Value"};
    static const bool align[] = {false, true, true};

    std::vector<std::vector<std::string>> rows;
    for (const auto& [category, pair] : totals) {
        rows.push_back({std::string{name(category)},
                        std::to_string(pair.first),
                        pair.second.str()});
    }
    writeTable(headings, rows, align);
}

}  // namespace stores

// --------------------------------------------------------------------- main

int main() {
    using namespace stores;

    Store store;
    store.add({"SKU-4102", "Mooring rope, 24mm", Category::Deck,
               Count{48}, Count{12}, Money::fromPounds(34.50), "Ashworth & Pell"});
    store.add({"SKU-4210", "Life jacket, adult", Category::Safety,
               Count{310}, Count{250}, Money::fromPounds(27.95), "Kestrel Marine"});
    store.add({"SKU-4211", "Life jacket, child", Category::Safety,
               Count{96}, Count{120}, Money::fromPounds(24.40), "Kestrel Marine"});
    store.add({"SKU-4330", "Deck paint, grey, 5L", Category::Maintenance,
               Count{17}, Count{24}, Money::fromPounds(88.75), "Halloway Coatings"});
    store.add({"SKU-4440", "Engine oil, 20L", Category::Engineering,
               Count{14}, Count{18}, Money::fromPounds(96.30), "Fenwick Lubricants"});
    store.add({"SKU-4443", "Impeller, spare", Category::Engineering,
               Count{6}, Count{12}, Money::fromPounds(148.00), "Fenwick Lubricants"});

    std::cout << "--- opening stock ---\n";
    stockReport(store);
    std::cout << "\n  total value " << store.totalValue().str() << "\n";

    std::cout << "\n--- movements ---\n";
    const std::vector<Event> movements{
        Receipt{"SKU-4443", Count{18}, Money::fromPounds(139.00), "PO-2271"},
        Issue{"SKU-4102", Count{6}, "Kestrel"},
        Issue{"SKU-4210", Count{40}, "Harbour Loop"},
        Receipt{"SKU-4330", Count{36}, Money::fromPounds(91.20), "PO-2272"},
        Adjust{"SKU-4211", Count{-4}, "damaged in store"},
        Writeoff{"SKU-4440", Count{2}, "contaminated"},
        Receipt{"SKU-4211", Count{60}, Money::fromPounds(23.10), "PO-2273"},
    };
    for (const Event& event : movements) {
        store.apply(event);
        std::cout << "  " << describe(event) << '\n';
    }

    std::cout << "\n--- after movements ---\n";
    stockReport(store);
    std::cout << "\n  total value " << store.totalValue().str() << "\n";

    std::cout << "\n--- weighted average cost moved ---\n";
    for (std::string_view sku : {"SKU-4443", "SKU-4211", "SKU-4330"}) {
        std::cout << std::format("  {} now {}\n", sku, store.at(sku).unitCost.str());
    }

    std::cout << "\n--- below reorder level ---\n";
    auto low = store.all()
        | std::views::filter([](const Item& item) { return item.belowReorder(); });
    for (const Item& item : low) {
        std::cout << std::format("  {:<10} {:<22} {} on hand, reorder at {}\n",
                                 item.sku, item.description,
                                 item.onHand.str(), item.reorderAt.str());
    }

    std::cout << "\n--- by category ---\n";
    categoryReport(store);

    std::cout << "\n--- by supplier, dearest first ---\n";
    {
        std::map<std::string, Money> bySupplier;
        for (const Item& item : store.all()) bySupplier[item.supplier] += item.value();

        std::vector<std::pair<std::string, Money>> ranked{bySupplier.begin(),
                                                          bySupplier.end()};
        std::ranges::sort(ranked, std::ranges::greater{},
                          [](const auto& pair) { return pair.second; });
        for (const auto& [supplier, value] : ranked) {
            std::cout << std::format("  {:<22} {}\n", supplier, value.str());
        }
    }

    std::cout << "\n--- a transaction that fails rolls back ---\n";
    const Money before = store.totalValue();
    const Count ropeBefore = store.at("SKU-4102").onHand;
    try {
        Transaction transaction(store);
        transaction.apply(Issue{"SKU-4102", Count{10}, "Halloway"});
        transaction.apply(Issue{"SKU-4443", Count{9999}, "Halloway"});   // too many
        transaction.commit();
        std::cout << "  (unexpectedly committed)\n";
    } catch (const StoresError& error) {
        std::cout << "  refused: " << error.what() << '\n';
    }
    std::cout << std::format("  rope still {} (was {}), total still {} (was {})\n",
                             store.at("SKU-4102").onHand.str(), ropeBefore.str(),
                             store.totalValue().str(), before.str());

    std::cout << "\n--- a transaction that succeeds commits ---\n";
    {
        Transaction transaction(store);
        transaction.apply(Issue{"SKU-4102", Count{10}, "Halloway"});
        transaction.apply(Issue{"SKU-4210", Count{25}, "Halloway"});
        transaction.commit();
    }
    std::cout << std::format("  rope now {}\n", store.at("SKU-4102").onHand.str());

    std::cout << "\n--- errors ---\n";
    for (const auto& attempt : std::vector<std::function<void()>>{
             [&] { (void)store.at("SKU-0000"); },
             [&] { store.apply(Issue{"SKU-4443", Count{9999}, "Nowhere"}); },
             [&] { store.add({"SKU-4102", "duplicate", Category::Deck,
                              Count{}, Count{}, Money{}, ""}); },
         }) {
        try {
            attempt();
            std::cout << "  (unexpectedly allowed)\n";
        } catch (const StoresError& error) {
            std::cout << "  " << error.what() << '\n';
        }
    }

    std::cout << "\n--- units are checked at compile time ---\n";
    const Length rope = Length{24.0} + Length{6.5};
    const Volume oil  = Volume{20.0} * 3;
    std::cout << std::format("  {} of rope, {} of oil\n", rope.str(), oil.str());
    std::cout << "  rope + oil does not compile, which is the point\n";

    std::cout << std::format("\n  {} event(s) on the journal\n",
                             store.journal().size());
    return 0;
}

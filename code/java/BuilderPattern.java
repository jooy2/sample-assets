// A builder keeps a class with many optional fields readable at the call
// site, and lets the finished object stay immutable.

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public class BuilderPattern {

    static final class Product {
        private final String sku;
        private final String name;
        private final double price;
        private final String currency;
        private final int stock;
        private final List<String> tags;
        private final LocalDate releasedOn;

        private Product(Builder builder) {
            this.sku = builder.sku;
            this.name = builder.name;
            this.price = builder.price;
            this.currency = builder.currency;
            this.stock = builder.stock;
            this.tags = List.copyOf(builder.tags);
            this.releasedOn = builder.releasedOn;
        }

        static Builder builder(String sku, String name) {
            return new Builder(sku, name);
        }

        @Override
        public String toString() {
            return "%s %s %.2f %s, stock %d, tags %s, released %s"
                    .formatted(sku, name, price, currency, stock, tags, releasedOn);
        }

        static final class Builder {
            private final String sku;
            private final String name;
            private double price;
            private String currency = "USD";
            private int stock;
            private final List<String> tags = new ArrayList<>();
            private LocalDate releasedOn = LocalDate.now();

            private Builder(String sku, String name) {
                this.sku = Objects.requireNonNull(sku, "sku");
                this.name = Objects.requireNonNull(name, "name");
            }

            Builder price(double price, String currency) {
                this.price = price;
                this.currency = currency;
                return this;
            }

            Builder stock(int stock) {
                this.stock = stock;
                return this;
            }

            Builder tag(String tag) {
                tags.add(tag);
                return this;
            }

            Builder releasedOn(LocalDate date) {
                this.releasedOn = date;
                return this;
            }

            Product build() {
                if (price <= 0) {
                    throw new IllegalStateException("price must be set before building");
                }
                return new Product(this);
            }
        }
    }

    public static void main(String[] args) {
        Product mug = Product.builder("KIT-0001", "Matte Ceramic Mug")
                .price(12.50, "USD")
                .stock(240)
                .tag("bestseller")
                .tag("dishwasher-safe")
                .releasedOn(LocalDate.of(2024, 3, 18))
                .build();

        System.out.println(mug);

        // Only the required arguments, with the defaults doing the rest.
        System.out.println(Product.builder("STA-0007", "Desk Planner").price(9.00, "GBP").build());

        try {
            Product.builder("OUT-0002", "Dry Bag").stock(5).build();
        } catch (IllegalStateException error) {
            System.out.println("rejected: " + error.getMessage());
        }
    }
}

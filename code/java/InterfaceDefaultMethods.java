// An interface can carry default and static methods, so behaviour can be
// added without breaking the classes that already implement it.

import java.util.List;

public class InterfaceDefaultMethods {

    interface Payable {
        double baseSalary();

        /** Implementations inherit this unless they override it. */
        default double monthlyPay() {
            return baseSalary() / 12;
        }

        default String payslip() {
            return String.format("%s: %.2f per month", getClass().getSimpleName(), monthlyPay());
        }

        /** A static method belongs to the interface, not to implementations. */
        static double annualFrom(double monthly) {
            return monthly * 12;
        }
    }

    interface Bonused {
        double bonus();

        default double monthlyPay() {
            return bonus() / 12;
        }
    }

    static class Employee implements Payable {
        private final double base;

        Employee(double base) {
            this.base = base;
        }

        @Override
        public double baseSalary() {
            return base;
        }
    }

    static class Engineer extends Employee {
        private final double bonus;

        Engineer(double base, double bonus) {
            super(base);
            this.bonus = bonus;
        }

        @Override
        public double monthlyPay() {
            return super.monthlyPay() + bonus / 12;
        }
    }

    /** When two interfaces offer the same default, the class must choose. */
    static class Contractor implements Payable, Bonused {
        @Override
        public double baseSalary() {
            return 0;
        }

        @Override
        public double bonus() {
            return 96_000;
        }

        @Override
        public double monthlyPay() {
            return Bonused.super.monthlyPay();
        }
    }

    public static void main(String[] args) {
        List<Payable> staff = List.of(
                new Employee(96_000), new Engineer(132_000, 18_000), new Contractor());

        for (Payable person : staff) {
            System.out.println(person.payslip());
        }

        System.out.printf("annual from 8000 a month: %.2f%n", Payable.annualFrom(8_000));
    }
}

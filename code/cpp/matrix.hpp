// A header-only fixed-size matrix template: no .cpp file, no build step.

#ifndef SAMPLE_MATRIX_HPP
#define SAMPLE_MATRIX_HPP

#include <array>
#include <cstddef>
#include <ostream>

template <typename T, std::size_t Rows, std::size_t Columns>
class Matrix {
public:
    Matrix() : cells_{} {}

    T& at(std::size_t row, std::size_t column) { return cells_[row * Columns + column]; }
    const T& at(std::size_t row, std::size_t column) const {
        return cells_[row * Columns + column];
    }

    static constexpr std::size_t rows() { return Rows; }
    static constexpr std::size_t columns() { return Columns; }

    Matrix operator+(const Matrix& other) const {
        Matrix sum;
        for (std::size_t i = 0; i < cells_.size(); ++i) {
            sum.cells_[i] = cells_[i] + other.cells_[i];
        }
        return sum;
    }

    template <std::size_t Other>
    Matrix<T, Rows, Other> operator*(const Matrix<T, Columns, Other>& right) const {
        Matrix<T, Rows, Other> product;
        for (std::size_t row = 0; row < Rows; ++row) {
            for (std::size_t column = 0; column < Other; ++column) {
                T sum{};
                for (std::size_t k = 0; k < Columns; ++k) {
                    sum += at(row, k) * right.at(k, column);
                }
                product.at(row, column) = sum;
            }
        }
        return product;
    }

    friend std::ostream& operator<<(std::ostream& out, const Matrix& matrix) {
        for (std::size_t row = 0; row < Rows; ++row) {
            for (std::size_t column = 0; column < Columns; ++column) {
                out << matrix.at(row, column) << (column + 1 == Columns ? '\n' : ' ');
            }
        }
        return out;
    }

private:
    std::array<T, Rows * Columns> cells_;
};

#endif // SAMPLE_MATRIX_HPP

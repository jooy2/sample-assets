// MatrixAlgebra.swift — a dense matrix type and the linear algebra to go with it.
//
// Value semantics, operator overloading, subscripting, LU decomposition with
// partial pivoting, determinant, inverse, linear solving, least squares, and
// a power-iteration eigenvalue. Errors are thrown, not returned as sentinel
// values.
//
//   swiftc -O MatrixAlgebra.swift -o matrix && ./matrix
//   swift MatrixAlgebra.swift
//
// One file, Foundation only for formatting.

import Foundation

// ------------------------------------------------------------------- errors

enum MatrixError: Error, CustomStringConvertible {
    case dimensionMismatch(String)
    case notSquare(rows: Int, columns: Int)
    case singular
    case emptyMatrix
    case indexOutOfRange(row: Int, column: Int)

    var description: String {
        switch self {
        case .dimensionMismatch(let detail):
            return "dimension mismatch: \(detail)"
        case .notSquare(let rows, let columns):
            return "matrix is \(rows)x\(columns), not square"
        case .singular:
            return "matrix is singular to working precision"
        case .emptyMatrix:
            return "matrix has no elements"
        case .indexOutOfRange(let row, let column):
            return "index (\(row), \(column)) is outside the matrix"
        }
    }
}

// ------------------------------------------------------------------- matrix

/// A dense, row-major matrix of doubles. A struct, so assigning one copies it.
struct Matrix {
    private(set) var rows: Int
    private(set) var columns: Int
    private(set) var elements: [Double]

    // -------------------------------------------------------- construction

    init(rows: Int, columns: Int, repeating value: Double = 0) {
        precondition(rows > 0 && columns > 0, "a matrix needs at least one element")
        self.rows = rows
        self.columns = columns
        self.elements = Array(repeating: value, count: rows * columns)
    }

    init(_ grid: [[Double]]) throws {
        guard let first = grid.first, !first.isEmpty else {
            throw MatrixError.emptyMatrix
        }
        guard grid.allSatisfy({ $0.count == first.count }) else {
            throw MatrixError.dimensionMismatch("rows have differing lengths")
        }
        self.rows = grid.count
        self.columns = first.count
        self.elements = grid.flatMap { $0 }
    }

    static func identity(_ size: Int) -> Matrix {
        var result = Matrix(rows: size, columns: size)
        for i in 0..<size { result[i, i] = 1 }
        return result
    }

    static func diagonal(_ values: [Double]) -> Matrix {
        var result = Matrix(rows: values.count, columns: values.count)
        for (i, value) in values.enumerated() { result[i, i] = value }
        return result
    }

    /// A column vector, which is just an n x 1 matrix.
    static func column(_ values: [Double]) -> Matrix {
        var result = Matrix(rows: values.count, columns: 1)
        for (i, value) in values.enumerated() { result[i, 0] = value }
        return result
    }

    // ------------------------------------------------------------- access

    subscript(row: Int, column: Int) -> Double {
        get {
            precondition(row >= 0 && row < rows && column >= 0 && column < columns,
                         "index out of range")
            return elements[row * columns + column]
        }
        set {
            precondition(row >= 0 && row < rows && column >= 0 && column < columns,
                         "index out of range")
            elements[row * columns + column] = newValue
        }
    }

    /// A whole row, as an array. Read only, to keep the setter simple.
    subscript(row row: Int) -> [Double] {
        Array(elements[(row * columns)..<((row + 1) * columns)])
    }

    subscript(column column: Int) -> [Double] {
        (0..<rows).map { self[$0, column] }
    }

    var isSquare: Bool { rows == columns }

    var shape: (rows: Int, columns: Int) { (rows, columns) }

    // ------------------------------------------------------- element-wise

    func map(_ transform: (Double) -> Double) -> Matrix {
        var result = self
        result.elements = elements.map(transform)
        return result
    }

    var transposed: Matrix {
        var result = Matrix(rows: columns, columns: rows)
        for r in 0..<rows {
            for c in 0..<columns {
                result[c, r] = self[r, c]
            }
        }
        return result
    }

    var trace: Double {
        get throws {
            guard isSquare else { throw MatrixError.notSquare(rows: rows, columns: columns) }
            return (0..<rows).reduce(0) { $0 + self[$1, $1] }
        }
    }

    /// The Frobenius norm: the square root of the sum of the squares.
    var norm: Double {
        (elements.reduce(0) { $0 + $1 * $1 }).squareRoot()
    }

    // -------------------------------------------------------- arithmetic

    static func + (lhs: Matrix, rhs: Matrix) throws -> Matrix {
        try lhs.combine(rhs, with: +)
    }

    static func - (lhs: Matrix, rhs: Matrix) throws -> Matrix {
        try lhs.combine(rhs, with: -)
    }

    static func * (lhs: Matrix, rhs: Double) -> Matrix {
        lhs.map { $0 * rhs }
    }

    static func * (lhs: Double, rhs: Matrix) -> Matrix {
        rhs.map { $0 * lhs }
    }

    static func * (lhs: Matrix, rhs: Matrix) throws -> Matrix {
        guard lhs.columns == rhs.rows else {
            throw MatrixError.dimensionMismatch(
                "cannot multiply \(lhs.rows)x\(lhs.columns) by \(rhs.rows)x\(rhs.columns)")
        }

        var result = Matrix(rows: lhs.rows, columns: rhs.columns)
        // ikj order: the inner loop walks both operands along contiguous
        // memory, which matters more than the arithmetic does.
        for i in 0..<lhs.rows {
            for k in 0..<lhs.columns {
                let scale = lhs[i, k]
                if scale == 0 { continue }
                for j in 0..<rhs.columns {
                    result[i, j] += scale * rhs[k, j]
                }
            }
        }
        return result
    }

    private func combine(_ other: Matrix,
                         with operation: (Double, Double) -> Double) throws -> Matrix {
        guard rows == other.rows, columns == other.columns else {
            throw MatrixError.dimensionMismatch(
                "\(rows)x\(columns) against \(other.rows)x\(other.columns)")
        }
        var result = self
        for i in 0..<elements.count {
            result.elements[i] = operation(elements[i], other.elements[i])
        }
        return result
    }

    // ------------------------------------------------- LU decomposition

    /// The result of factoring A into P*A = L*U.
    struct LU {
        let combined: Matrix       // L below the diagonal, U on and above it
        let permutation: [Int]
        let swaps: Int
        let size: Int

        var lower: Matrix {
            var result = Matrix.identity(size)
            for r in 1..<size {
                for c in 0..<r { result[r, c] = combined[r, c] }
            }
            return result
        }

        var upper: Matrix {
            var result = Matrix(rows: size, columns: size)
            for r in 0..<size {
                for c in r..<size { result[r, c] = combined[r, c] }
            }
            return result
        }
    }

    /// Factor with partial pivoting: at each step the largest available
    /// element becomes the pivot, which is what keeps the arithmetic stable.
    func decomposed() throws -> LU {
        guard isSquare else { throw MatrixError.notSquare(rows: rows, columns: columns) }

        var work = self
        var permutation = Array(0..<rows)
        var swaps = 0

        for pivot in 0..<rows {
            var best = pivot
            var bestValue = abs(work[pivot, pivot])
            for candidate in (pivot + 1)..<rows where abs(work[candidate, pivot]) > bestValue {
                best = candidate
                bestValue = abs(work[candidate, pivot])
            }

            if bestValue < 1e-12 { throw MatrixError.singular }

            if best != pivot {
                for c in 0..<columns {
                    let held = work[pivot, c]
                    work[pivot, c] = work[best, c]
                    work[best, c] = held
                }
                permutation.swapAt(pivot, best)
                swaps += 1
            }

            for row in (pivot + 1)..<rows {
                let factor = work[row, pivot] / work[pivot, pivot]
                work[row, pivot] = factor          // store L in place
                for c in (pivot + 1)..<columns {
                    work[row, c] -= factor * work[pivot, c]
                }
            }
        }

        return LU(combined: work, permutation: permutation, swaps: swaps, size: rows)
    }

    var determinant: Double {
        get throws {
            guard isSquare else { throw MatrixError.notSquare(rows: rows, columns: columns) }
            do {
                let lu = try decomposed()
                var product = lu.swaps % 2 == 0 ? 1.0 : -1.0
                for i in 0..<rows { product *= lu.combined[i, i] }
                return product
            } catch MatrixError.singular {
                return 0    // a singular matrix has determinant zero, not an error
            }
        }
    }

    /// Solve Ax = b for a single right-hand side.
    func solve(_ b: [Double]) throws -> [Double] {
        guard isSquare else { throw MatrixError.notSquare(rows: rows, columns: columns) }
        guard b.count == rows else {
            throw MatrixError.dimensionMismatch("b has \(b.count) entries, need \(rows)")
        }

        let lu = try decomposed()

        // Forward substitution through L, applying the row permutation.
        var y = [Double](repeating: 0, count: rows)
        for i in 0..<rows {
            var sum = b[lu.permutation[i]]
            for j in 0..<i { sum -= lu.combined[i, j] * y[j] }
            y[i] = sum
        }

        // Back substitution through U.
        var x = [Double](repeating: 0, count: rows)
        for i in stride(from: rows - 1, through: 0, by: -1) {
            var sum = y[i]
            for j in (i + 1)..<rows { sum -= lu.combined[i, j] * x[j] }
            x[i] = sum / lu.combined[i, i]
        }
        return x
    }

    var inverse: Matrix {
        get throws {
            guard isSquare else { throw MatrixError.notSquare(rows: rows, columns: columns) }
            var result = Matrix(rows: rows, columns: columns)
            for column in 0..<columns {
                var unit = [Double](repeating: 0, count: rows)
                unit[column] = 1
                let solved = try solve(unit)
                for row in 0..<rows { result[row, column] = solved[row] }
            }
            return result
        }
    }

    /// Least squares by the normal equations. Quick, and less accurate than a
    /// QR factorisation would be; adequate for a well-conditioned fit.
    static func leastSquares(_ design: Matrix, _ observations: [Double]) throws -> [Double] {
        let transposed = design.transposed
        let normal = try transposed * design
        let rhs = try transposed * Matrix.column(observations)
        return try normal.solve(rhs[column: 0])
    }

    /// The dominant eigenvalue, by repeated multiplication.
    func dominantEigenvalue(iterations: Int = 500,
                            tolerance: Double = 1e-12) throws -> (value: Double,
                                                                  vector: [Double]) {
        guard isSquare else { throw MatrixError.notSquare(rows: rows, columns: columns) }

        var vector = [Double](repeating: 1, count: rows)
        var eigenvalue = 0.0

        for _ in 0..<iterations {
            var next = [Double](repeating: 0, count: rows)
            for r in 0..<rows {
                for c in 0..<columns { next[r] += self[r, c] * vector[c] }
            }

            let length = (next.reduce(0) { $0 + $1 * $1 }).squareRoot()
            guard length > tolerance else { throw MatrixError.singular }
            next = next.map { $0 / length }

            // Rayleigh quotient, which converges faster than the norm alone.
            var quotient = 0.0
            for r in 0..<rows {
                for c in 0..<columns { quotient += next[r] * self[r, c] * next[c] }
            }

            if abs(quotient - eigenvalue) < tolerance {
                return (quotient, next)
            }
            eigenvalue = quotient
            vector = next
        }
        return (eigenvalue, vector)
    }
}

// ---------------------------------------------------------- presentation

extension Matrix: CustomStringConvertible {
    var description: String {
        // One format for the whole matrix: mixing "10" and "2.5000" in the
        // same grid makes the columns look ragged even when they line up.
        let needsDecimals = elements.contains { value in
            let cleaned = abs(value) < 5e-7 ? 0 : value
            return cleaned != cleaned.rounded() || abs(cleaned) >= 1e9
        }

        let cells = (0..<rows).map { row in
            (0..<columns).map { column -> String in
                let value = self[row, column]
                let cleaned = abs(value) < 5e-7 ? 0 : value
                return needsDecimals ? String(format: "%.4f", cleaned)
                                     : String(Int(cleaned))
            }
        }
        let width = cells.flatMap { $0 }.map(\.count).max() ?? 1

        return cells.map { row in
            "  [ " + row.map { String(repeating: " ", count: width - $0.count) + $0 }
                .joined(separator: "  ") + " ]"
        }.joined(separator: "\n")
    }

    static func format(_ value: Double) -> String {
        // -0 prints as "-0", which is correct and looks like a mistake.
        let cleaned = abs(value) < 5e-7 ? 0 : value
        if cleaned == cleaned.rounded() && abs(cleaned) < 1e9 {
            return String(Int(cleaned))
        }
        return String(format: "%.4f", cleaned)
    }
}

extension Matrix: Equatable {
    static func == (lhs: Matrix, rhs: Matrix) -> Bool {
        lhs.rows == rhs.rows && lhs.columns == rhs.columns
            && zip(lhs.elements, rhs.elements).allSatisfy { abs($0 - $1) < 1e-9 }
    }
}

// ------------------------------------------------------------------- demo

func heading(_ text: String) {
    print("\n--- \(text) ---")
}

func vectorText(_ values: [Double]) -> String {
    "[" + values.map(Matrix.format).joined(separator: ", ") + "]"
}

func runDemonstration() throws {
    let a = try Matrix([
        [4, -2, 1],
        [-2, 4, -2],
        [1, -2, 4],
    ])

    let b = try Matrix([
        [1, 2, 3],
        [0, 1, 4],
        [5, 6, 0],
    ])

    heading("two matrices")
    print(a)
    print()
    print(b)

    heading("arithmetic")
    print("a + b:")
    print(try a + b)
    print("\na * b:")
    print(try a * b)
    print("\n2.5 * a:")
    print(2.5 * a)
    print("\na transposed (a is symmetric, so unchanged): \(a.transposed == a)")

    heading("LU decomposition of b")
    let lu = try b.decomposed()
    print("L:")
    print(lu.lower)
    print("\nU:")
    print(lu.upper)
    print("\nrow permutation: \(lu.permutation), \(lu.swaps) swap(s)")
    print("L * U reproduces the permuted b: ", terminator: "")
    let reconstructed = try lu.lower * lu.upper
    var permuted = Matrix(rows: 3, columns: 3)
    for (target, source) in lu.permutation.enumerated() {
        for c in 0..<3 { permuted[target, c] = b[source, c] }
    }
    print(reconstructed == permuted)

    heading("determinant and trace")
    print("det(a) = \(Matrix.format(try a.determinant))")
    print("det(b) = \(Matrix.format(try b.determinant))")
    print("tr(a)  = \(Matrix.format(try a.trace))")
    print("|a|    = \(String(format: "%.4f", a.norm))")

    heading("inverse")
    let inverse = try b.inverse
    print(inverse)
    print("\nb * inverse(b) is the identity: ", terminator: "")
    print(try b * inverse == Matrix.identity(3))

    heading("solving a system")
    // 4x - 2y +  z = 11
    // -2x + 4y - 2z = -16
    //   x - 2y + 4z = 17
    let rhs = [11.0, -16.0, 17.0]
    let solution = try a.solve(rhs)
    print("a x = \(vectorText(rhs))")
    print("x   = \(vectorText(solution))")

    var check = [Double](repeating: 0, count: 3)
    for r in 0..<3 {
        for c in 0..<3 { check[r] += a[r, c] * solution[c] }
    }
    print("a * x back = \(vectorText(check))")

    heading("least squares fit")
    // Fit y = m*x + c to points that do not sit on a line.
    let xs: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
    let ys: [Double] = [2.1, 4.3, 5.8, 8.4, 9.9, 12.4, 14.1, 16.2]
    var design = Matrix(rows: xs.count, columns: 2)
    for (i, x) in xs.enumerated() {
        design[i, 0] = x
        design[i, 1] = 1
    }
    let fit = try Matrix.leastSquares(design, ys)
    print("y = \(String(format: "%.4f", fit[0]))x + \(String(format: "%.4f", fit[1]))")

    let residuals = zip(xs, ys).map { x, y in y - (fit[0] * x + fit[1]) }
    let rss = residuals.reduce(0) { $0 + $1 * $1 }
    print("residual sum of squares: \(String(format: "%.5f", rss))")

    heading("dominant eigenvalue of a")
    let (eigenvalue, eigenvector) = try a.dominantEigenvalue()
    print("lambda = \(String(format: "%.6f", eigenvalue))")
    print("vector = \(vectorText(eigenvector))")

    var image = [Double](repeating: 0, count: 3)
    for r in 0..<3 {
        for c in 0..<3 { image[r] += a[r, c] * eigenvector[c] }
    }
    print("a * v  = \(vectorText(image))")
    print("l * v  = \(vectorText(eigenvector.map { $0 * eigenvalue }))")

    heading("value semantics")
    var copy = a
    copy[0, 0] = 999
    print("original still has a[0,0] = \(Matrix.format(a[0, 0]))")
    print("the copy has         [0,0] = \(Matrix.format(copy[0, 0]))")

    heading("errors")
    let singular = try Matrix([
        [1, 2, 3],
        [2, 4, 6],
        [1, 1, 1],
    ])
    print("det(singular) = \(Matrix.format(try singular.determinant))")

    let attempts: [(String, () throws -> Void)] = [
        ("inverse of a singular matrix", { _ = try singular.inverse }),
        ("multiply 3x3 by 2x2", { _ = try a * Matrix.identity(2) }),
        ("add 3x3 to 2x2", { _ = try a + Matrix.identity(2) }),
        ("determinant of 2x3", {
            _ = try Matrix([[1, 2, 3], [4, 5, 6]]).determinant
        }),
        ("ragged input", { _ = try Matrix([[1, 2], [3]]) }),
    ]
    for (label, attempt) in attempts {
        do {
            try attempt()
            print("  \(label): unexpectedly allowed")
        } catch let error as MatrixError {
            print("  \(label): \(error)")
        }
    }
}

do {
    try runDemonstration()
} catch {
    print("failed: \(error)")
    exit(1)
}

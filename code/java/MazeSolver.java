import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.PriorityQueue;
import java.util.Random;
import java.util.Set;

/**
 * Grid path-finding: parse a maze, solve it four ways, compare the results,
 * and render the answer.
 *
 * Implements breadth-first search, Dijkstra over weighted terrain, A* with a
 * Manhattan heuristic, and a right-hand wall follower, plus a random maze
 * generator so the solvers have something new to chew on.
 *
 * <pre>
 *   javac MazeSolver.java
 *   java MazeSolver
 *   java MazeSolver 31 15 20270902   # width height seed
 * </pre>
 *
 * The point of having four is the comparison: they visit very different
 * numbers of cells to reach the same answer, and one of them is not
 * guaranteed to reach it at all.
 */
public final class MazeSolver {

    private MazeSolver() {
    }

    // ------------------------------------------------------------ the grid

    /** A position in the grid. A record, so it works as a map key for free. */
    public record Cell(int row, int column) {

        public Cell step(Direction direction) {
            return new Cell(row + direction.rowDelta, column + direction.columnDelta);
        }

        public int manhattanTo(Cell other) {
            return Math.abs(row - other.row) + Math.abs(column - other.column);
        }

        @Override
        public String toString() {
            return "(" + row + "," + column + ")";
        }
    }

    public enum Direction {
        NORTH(-1, 0, '^'), EAST(0, 1, '>'), SOUTH(1, 0, 'v'), WEST(0, -1, '<');

        final int rowDelta;
        final int columnDelta;
        final char arrow;

        Direction(int rowDelta, int columnDelta, char arrow) {
            this.rowDelta = rowDelta;
            this.columnDelta = columnDelta;
            this.arrow = arrow;
        }

        Direction turnRight() {
            return values()[(ordinal() + 1) % 4];
        }

        Direction turnLeft() {
            return values()[(ordinal() + 3) % 4];
        }

        Direction reverse() {
            return values()[(ordinal() + 2) % 4];
        }
    }

    /**
     * A maze read from text. Characters carry a movement cost, so the same
     * grid serves both the unweighted and the weighted solvers.
     *
     * <pre>
     *   '#'  wall, impassable
     *   ' '  open, cost 1
     *   '~'  water, cost 5
     *   ':'  gravel, cost 3
     *   'S'  start
     *   'E'  end
     * </pre>
     */
    public static final class Maze {

        private final char[][] grid;
        private final int rows;
        private final int columns;
        private final Cell start;
        private final Cell end;

        private Maze(char[][] grid, Cell start, Cell end) {
            this.grid = grid;
            this.rows = grid.length;
            this.columns = grid[0].length;
            this.start = start;
            this.end = end;
        }

        public static Maze parse(String text) {
            String[] lines = text.strip().split("\n");
            int width = Arrays.stream(lines).mapToInt(String::length).max().orElse(0);

            char[][] grid = new char[lines.length][width];
            Cell start = null;
            Cell end = null;

            for (int row = 0; row < lines.length; row++) {
                Arrays.fill(grid[row], '#');
                for (int column = 0; column < lines[row].length(); column++) {
                    char symbol = lines[row].charAt(column);
                    grid[row][column] = symbol;
                    if (symbol == 'S') {
                        start = new Cell(row, column);
                    }
                    if (symbol == 'E') {
                        end = new Cell(row, column);
                    }
                }
            }

            if (start == null || end == null) {
                throw new IllegalArgumentException("the maze needs both an S and an E");
            }
            return new Maze(grid, start, end);
        }

        public int rows() {
            return rows;
        }

        public int columns() {
            return columns;
        }

        public Cell start() {
            return start;
        }

        public Cell end() {
            return end;
        }

        public char at(Cell cell) {
            return inside(cell) ? grid[cell.row()][cell.column()] : '#';
        }

        public boolean inside(Cell cell) {
            return cell.row() >= 0 && cell.row() < rows
                    && cell.column() >= 0 && cell.column() < columns;
        }

        public boolean passable(Cell cell) {
            return inside(cell) && grid[cell.row()][cell.column()] != '#';
        }

        /** What it costs to enter a cell. Walls are unreachable, not expensive. */
        public int cost(Cell cell) {
            return switch (at(cell)) {
                case '~' -> 5;
                case ':' -> 3;
                case '#' -> Integer.MAX_VALUE;
                default -> 1;
            };
        }

        public List<Cell> neighbours(Cell cell) {
            List<Cell> out = new ArrayList<>(4);
            for (Direction direction : Direction.values()) {
                Cell next = cell.step(direction);
                if (passable(next)) {
                    out.add(next);
                }
            }
            return out;
        }

        /** Draw the maze with a path marked, and optionally the visited set shaded. */
        public String render(List<Cell> path, Set<Cell> visited) {
            Set<Cell> onPath = path == null ? Set.of() : Set.copyOf(path);
            StringBuilder out = new StringBuilder();

            for (int row = 0; row < rows; row++) {
                for (int column = 0; column < columns; column++) {
                    Cell cell = new Cell(row, column);
                    char symbol = grid[row][column];

                    if (cell.equals(start)) {
                        out.append('S');
                    } else if (cell.equals(end)) {
                        out.append('E');
                    } else if (onPath.contains(cell)) {
                        out.append('o');
                    } else if (visited != null && visited.contains(cell) && symbol != '#') {
                        out.append('.');
                    } else {
                        out.append(symbol);
                    }
                }
                out.append('\n');
            }
            return out.toString();
        }
    }

    // ------------------------------------------------------------ the result

    /**
     * What a solver found: the path, its cost, and how much of the maze the
     * solver had to look at to find it.
     */
    public record Solution(
            String method,
            List<Cell> path,
            int cost,
            int visited,
            boolean optimal) {

        public boolean found() {
            return !path.isEmpty();
        }

        public int steps() {
            return Math.max(0, path.size() - 1);
        }

        public String summary() {
            if (!found()) {
                return "%-16s no path found after visiting %d cell(s)"
                        .formatted(method, visited);
            }
            return "%-16s %3d step(s), cost %4d, visited %4d %s".formatted(
                    method, steps(), cost, visited, optimal ? "" : "(not guaranteed optimal)");
        }
    }

    /** Walk the came-from map backwards from the end to build the path. */
    private static List<Cell> reconstruct(Map<Cell, Cell> cameFrom, Cell start, Cell end) {
        if (!cameFrom.containsKey(end) && !end.equals(start)) {
            return List.of();
        }
        Deque<Cell> path = new ArrayDeque<>();
        Cell node = end;
        while (node != null) {
            path.addFirst(node);
            if (node.equals(start)) {
                break;
            }
            node = cameFrom.get(node);
        }
        return List.copyOf(path);
    }

    private static int costOf(Maze maze, List<Cell> path) {
        return path.stream().skip(1).mapToInt(maze::cost).sum();
    }

    // -------------------------------------------------------------- solvers

    /**
     * Breadth-first search: fewest steps, ignoring terrain cost. Correct when
     * every move costs the same, and misleading when it does not.
     */
    public static Solution breadthFirst(Maze maze) {
        Deque<Cell> queue = new ArrayDeque<>();
        Map<Cell, Cell> cameFrom = new HashMap<>();
        Set<Cell> seen = new java.util.LinkedHashSet<>();

        queue.add(maze.start());
        seen.add(maze.start());

        while (!queue.isEmpty()) {
            Cell current = queue.removeFirst();
            if (current.equals(maze.end())) {
                break;
            }
            for (Cell next : maze.neighbours(current)) {
                if (seen.add(next)) {
                    cameFrom.put(next, current);
                    queue.addLast(next);
                }
            }
        }

        List<Cell> path = reconstruct(cameFrom, maze.start(), maze.end());
        return new Solution("breadth-first", path, costOf(maze, path), seen.size(), true);
    }

    /**
     * Depth-first search: finds a path, and rarely a good one. Included
     * because the contrast with breadth-first is the whole lesson.
     */
    public static Solution depthFirst(Maze maze) {
        Deque<Cell> stack = new ArrayDeque<>();
        Map<Cell, Cell> cameFrom = new HashMap<>();
        Set<Cell> seen = new java.util.LinkedHashSet<>();

        stack.push(maze.start());
        seen.add(maze.start());

        while (!stack.isEmpty()) {
            Cell current = stack.pop();
            if (current.equals(maze.end())) {
                break;
            }
            for (Cell next : maze.neighbours(current)) {
                if (seen.add(next)) {
                    cameFrom.put(next, current);
                    stack.push(next);
                }
            }
        }

        List<Cell> path = reconstruct(cameFrom, maze.start(), maze.end());
        return new Solution("depth-first", path, costOf(maze, path), seen.size(), false);
    }

    /** Dijkstra: cheapest path once terrain costs differ. */
    public static Solution dijkstra(Maze maze) {
        Map<Cell, Integer> best = new HashMap<>();
        Map<Cell, Cell> cameFrom = new HashMap<>();
        Set<Cell> settled = new java.util.LinkedHashSet<>();

        PriorityQueue<Cell> frontier = new PriorityQueue<>(
                Comparator.comparingInt(cell -> best.getOrDefault(cell, Integer.MAX_VALUE)));

        best.put(maze.start(), 0);
        frontier.add(maze.start());

        while (!frontier.isEmpty()) {
            Cell current = frontier.poll();
            if (!settled.add(current)) {
                continue;
            }
            if (current.equals(maze.end())) {
                break;
            }

            for (Cell next : maze.neighbours(current)) {
                int candidate = best.get(current) + maze.cost(next);
                if (candidate < best.getOrDefault(next, Integer.MAX_VALUE)) {
                    best.put(next, candidate);
                    cameFrom.put(next, current);
                    frontier.add(next);
                }
            }
        }

        List<Cell> path = reconstruct(cameFrom, maze.start(), maze.end());
        return new Solution("dijkstra", path, costOf(maze, path), settled.size(), true);
    }

    /**
     * A*: Dijkstra guided by a heuristic. The Manhattan distance never
     * overestimates when the cheapest move costs one, so the answer stays
     * optimal while far fewer cells are settled.
     */
    public static Solution aStar(Maze maze) {
        Map<Cell, Integer> best = new HashMap<>();
        Map<Cell, Cell> cameFrom = new HashMap<>();
        Set<Cell> settled = new java.util.LinkedHashSet<>();

        Cell goal = maze.end();
        Comparator<Cell> byEstimate = Comparator.comparingInt(
                cell -> best.getOrDefault(cell, Integer.MAX_VALUE / 2) + cell.manhattanTo(goal));
        PriorityQueue<Cell> frontier = new PriorityQueue<>(byEstimate);

        best.put(maze.start(), 0);
        frontier.add(maze.start());

        while (!frontier.isEmpty()) {
            Cell current = frontier.poll();
            if (!settled.add(current)) {
                continue;
            }
            if (current.equals(goal)) {
                break;
            }

            for (Cell next : maze.neighbours(current)) {
                int candidate = best.get(current) + maze.cost(next);
                if (candidate < best.getOrDefault(next, Integer.MAX_VALUE)) {
                    best.put(next, candidate);
                    cameFrom.put(next, current);
                    frontier.add(next);
                }
            }
        }

        List<Cell> path = reconstruct(cameFrom, maze.start(), goal);
        return new Solution("a-star", path, costOf(maze, path), settled.size(), true);
    }

    /**
     * The right-hand rule: keep a wall on your right and walk. Needs no memory
     * at all, and only works when the start and the goal are on the same wall
     * — an island in the middle of the maze defeats it entirely.
     */
    public static Solution wallFollower(Maze maze, int stepLimit) {
        List<Cell> path = new ArrayList<>();
        Set<Cell> seen = new java.util.LinkedHashSet<>();

        Cell current = maze.start();
        Direction facing = Direction.EAST;
        path.add(current);
        seen.add(current);

        for (int step = 0; step < stepLimit; step++) {
            if (current.equals(maze.end())) {
                return new Solution("wall-follower", List.copyOf(path),
                        costOf(maze, path), seen.size(), false);
            }

            Direction right = facing.turnRight();
            if (maze.passable(current.step(right))) {
                facing = right;
            } else if (!maze.passable(current.step(facing))) {
                facing = facing.turnLeft();
                if (!maze.passable(current.step(facing))) {
                    facing = facing.reverse();
                }
            }

            Cell next = current.step(facing);
            if (!maze.passable(next)) {
                break;
            }
            current = next;
            path.add(current);
            seen.add(current);
        }

        return new Solution("wall-follower", List.of(), 0, seen.size(), false);
    }

    // ------------------------------------------------------------ generation

    /**
     * Carve a perfect maze with a randomised depth-first walk, then punch a
     * few extra openings so that more than one route exists and scatter some
     * expensive terrain for Dijkstra to care about.
     */
    public static Maze generate(int width, int height, long seed) {
        int w = Math.max(5, width | 1);
        int h = Math.max(5, height | 1);
        Random random = new Random(seed);

        char[][] grid = new char[h][w];
        for (char[] row : grid) {
            Arrays.fill(row, '#');
        }

        Deque<Cell> stack = new ArrayDeque<>();
        Cell current = new Cell(1, 1);
        grid[1][1] = ' ';
        stack.push(current);

        while (!stack.isEmpty()) {
            current = stack.peek();
            List<Cell> candidates = new ArrayList<>();
            for (Direction direction : Direction.values()) {
                Cell target = new Cell(
                        current.row() + direction.rowDelta * 2,
                        current.column() + direction.columnDelta * 2);
                if (target.row() > 0 && target.row() < h - 1
                        && target.column() > 0 && target.column() < w - 1
                        && grid[target.row()][target.column()] == '#') {
                    candidates.add(target);
                }
            }

            if (candidates.isEmpty()) {
                stack.pop();
                continue;
            }

            Cell chosen = candidates.get(random.nextInt(candidates.size()));
            grid[(current.row() + chosen.row()) / 2][(current.column() + chosen.column()) / 2] = ' ';
            grid[chosen.row()][chosen.column()] = ' ';
            stack.push(chosen);
        }

        // A perfect maze has exactly one route between any two cells, which
        // makes every solver agree. Extra openings give them something to
        // disagree about.
        int extra = (w * h) / 60;
        for (int i = 0; i < extra; i++) {
            int row = 1 + random.nextInt(h - 2);
            int column = 1 + random.nextInt(w - 2);
            if (row % 2 == 1 || column % 2 == 1) {
                grid[row][column] = ' ';
            }
        }

        for (int row = 1; row < h - 1; row++) {
            for (int column = 1; column < w - 1; column++) {
                if (grid[row][column] != ' ') {
                    continue;
                }
                int roll = random.nextInt(100);
                if (roll < 8) {
                    grid[row][column] = '~';
                } else if (roll < 20) {
                    grid[row][column] = ':';
                }
            }
        }

        grid[1][1] = 'S';
        grid[h - 2][w - 2] = 'E';

        StringBuilder text = new StringBuilder();
        for (char[] row : grid) {
            text.append(new String(row)).append('\n');
        }
        return Maze.parse(text.toString());
    }

    // ------------------------------------------------------------------ main

    private static final String HAND_DRAWN = """
            #####################
            #S    #     :::     #
            # ### # ####:::#### #
            #   # #    #~~~~  # #
            ### # #### #~~~~# # #
            #   #    # #    # # #
            # ###### # ###### # #
            #      # #      #   #
            ###### # ###### #####
            #    # #      #     #
            # ## # ###### ##### #
            # #  #      #     # #
            # # ######### ### # #
            #   #       # # #   #
            # ### ##### # # #####
            #   #     # #      E#
            #####################
            """;

    public static void main(String[] args) {
        Maze maze = args.length >= 2
                ? generate(
                        Integer.parseInt(args[0]),
                        Integer.parseInt(args[1]),
                        args.length >= 3 ? Long.parseLong(args[2]) : 20270902L)
                : Maze.parse(HAND_DRAWN);

        System.out.printf("A %d x %d maze, %s to %s%n%n",
                maze.rows(), maze.columns(), maze.start(), maze.end());
        System.out.print(maze.render(null, null));

        List<Solution> solutions = List.of(
                breadthFirst(maze),
                depthFirst(maze),
                dijkstra(maze),
                aStar(maze),
                wallFollower(maze, maze.rows() * maze.columns() * 4));

        System.out.println("\n--- solvers ---");
        solutions.forEach(solution -> System.out.println("  " + solution.summary()));

        Optional<Solution> cheapest = solutions.stream()
                .filter(Solution::found)
                .min(Comparator.comparingInt(Solution::cost));

        cheapest.ifPresent(solution -> {
            System.out.printf("%n--- cheapest route: %s ---%n", solution.method());
            System.out.print(maze.render(solution.path(), null));
        });

        Solution bfs = solutions.get(0);
        Solution star = solutions.get(3);
        System.out.println("--- what the heuristic bought ---");
        System.out.printf("  breadth-first visited %d cells; a-star settled %d%n",
                bfs.visited(), star.visited());
        System.out.printf("  same cost: %s%n", bfs.cost() == star.cost()
                ? "yes — no terrain lay on the shortest route"
                : "no — breadth-first ignores terrain, so its route costs "
                        + (bfs.cost() - star.cost()) + " more");

        System.out.println("\n--- a-star's search, shaded ---");
        Solution shaded = aStar(maze);
        System.out.print(maze.render(shaded.path(), settledCells(maze)));
    }

    /** Re-run A* purely to collect the cells it settled, for the picture. */
    private static Set<Cell> settledCells(Maze maze) {
        Map<Cell, Integer> best = new HashMap<>();
        Set<Cell> settled = new java.util.LinkedHashSet<>();
        Cell goal = maze.end();

        PriorityQueue<Cell> frontier = new PriorityQueue<>(Comparator.comparingInt(
                cell -> best.getOrDefault(cell, Integer.MAX_VALUE / 2) + cell.manhattanTo(goal)));
        best.put(maze.start(), 0);
        frontier.add(maze.start());

        while (!frontier.isEmpty()) {
            Cell current = frontier.poll();
            if (!settled.add(current)) {
                continue;
            }
            if (current.equals(goal)) {
                break;
            }
            for (Cell next : maze.neighbours(current)) {
                int candidate = best.get(current) + maze.cost(next);
                if (candidate < best.getOrDefault(next, Integer.MAX_VALUE)) {
                    best.put(next, candidate);
                    frontier.add(next);
                }
            }
        }
        return settled;
    }
}

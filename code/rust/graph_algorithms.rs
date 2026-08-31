//! Graphs, and the algorithms worth having on one.
//!
//! A generic adjacency-list graph over any hashable node type, breadth-first
//! search, Dijkstra with a binary heap, topological ordering with cycle
//! reporting, Tarjan's strongly connected components, connected components on
//! the undirected view, and a minimum spanning tree by Kruskal with a
//! union-find.
//!
//! ```text
//! rustc -O graph_algorithms.rs -o graphs && ./graphs
//! rustc --test graph_algorithms.rs -o graph_tests && ./graph_tests
//! ```
//!
//! Traits and generics with bounds, `Ord` implemented by hand to invert a
//! max-heap into a min-heap, iterators, `Option`/`Result`, and interior
//! structure kept private behind a small API.
//!
//! No crates beyond the standard library. Every network below is invented.

use std::cmp::Reverse;
use std::collections::{BinaryHeap, BTreeMap, BTreeSet, HashMap, HashSet, VecDeque};
use std::fmt::{Debug, Display};
use std::hash::Hash;

// ------------------------------------------------------------------ traits

/// What a node has to be able to do. Every algorithm below is generic over
/// this rather than over a concrete type.
pub trait Node: Clone + Eq + Hash + Ord + Debug + Display {}

/// A blanket implementation, so any type meeting the bounds is a Node without
/// having to say so.
impl<T: Clone + Eq + Hash + Ord + Debug + Display> Node for T {}

/// An edge weight. Kept to non-negative integers on purpose: Dijkstra is
/// wrong on negative weights, and a type that cannot express them is a better
/// guard than a comment saying not to.
pub type Weight = u64;

// ------------------------------------------------------------------- graph

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Edge<N: Node> {
    pub from: N,
    pub to: N,
    pub weight: Weight,
}

impl<N: Node> Display for Edge<N> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} -> {} ({})", self.from, self.to, self.weight)
    }
}

/// A directed graph held as an adjacency list.
///
/// A BTreeMap rather than a HashMap so that iteration order is stable, which
/// is what makes the output of every algorithm below reproducible.
#[derive(Debug, Clone)]
pub struct Graph<N: Node> {
    adjacency: BTreeMap<N, Vec<(N, Weight)>>,
}

// Written out rather than derived: a derived Default would require N: Default,
// which nothing here needs.
impl<N: Node> Default for Graph<N> {
    fn default() -> Self {
        Graph { adjacency: BTreeMap::new() }
    }
}

impl<N: Node> Graph<N> {
    pub fn new() -> Self {
        Graph { adjacency: BTreeMap::new() }
    }

    /// Build from a list of edges, adding every endpoint as a node.
    pub fn from_edges<I>(edges: I) -> Self
    where
        I: IntoIterator<Item = (N, N, Weight)>,
    {
        let mut graph = Graph::new();
        for (from, to, weight) in edges {
            graph.add_edge(from, to, weight);
        }
        graph
    }

    pub fn add_node(&mut self, node: N) {
        self.adjacency.entry(node).or_default();
    }

    pub fn add_edge(&mut self, from: N, to: N, weight: Weight) {
        self.adjacency.entry(to.clone()).or_default();
        self.adjacency.entry(from).or_default().push((to, weight));
    }

    /// Add an edge in both directions, for a graph that is really undirected.
    pub fn add_undirected(&mut self, a: N, b: N, weight: Weight) {
        self.add_edge(a.clone(), b.clone(), weight);
        self.add_edge(b, a, weight);
    }

    pub fn node_count(&self) -> usize {
        self.adjacency.len()
    }

    pub fn edge_count(&self) -> usize {
        self.adjacency.values().map(Vec::len).sum()
    }

    pub fn contains(&self, node: &N) -> bool {
        self.adjacency.contains_key(node)
    }

    /// The nodes, in a stable order.
    pub fn nodes(&self) -> impl Iterator<Item = &N> + '_ {
        self.adjacency.keys()
    }

    /// A node's outgoing edges, or an empty slice if it has none.
    pub fn neighbours(&self, node: &N) -> &[(N, Weight)] {
        self.adjacency.get(node).map(Vec::as_slice).unwrap_or(&[])
    }

    /// Every edge, flattened.
    pub fn edges(&self) -> impl Iterator<Item = Edge<N>> + '_ {
        self.adjacency.iter().flat_map(|(from, targets)| {
            targets.iter().map(move |(to, weight)| Edge {
                from: from.clone(),
                to: to.clone(),
                weight: *weight,
            })
        })
    }

    /// How many edges arrive at each node.
    pub fn in_degrees(&self) -> BTreeMap<N, usize> {
        let mut degrees: BTreeMap<N, usize> =
            self.adjacency.keys().map(|node| (node.clone(), 0)).collect();
        for (_, targets) in &self.adjacency {
            for (to, _) in targets {
                *degrees.entry(to.clone()).or_insert(0) += 1;
            }
        }
        degrees
    }

    /// The same graph with every edge turned round.
    pub fn reversed(&self) -> Graph<N> {
        let mut graph = Graph::new();
        for node in self.nodes() {
            graph.add_node(node.clone());
        }
        for edge in self.edges() {
            graph.add_edge(edge.to, edge.from, edge.weight);
        }
        graph
    }

    // ------------------------------------------------------------- search

    /// Breadth-first order from a start node. Fewest hops, ignoring weight.
    pub fn breadth_first(&self, start: &N) -> Vec<N> {
        let mut order = Vec::new();
        if !self.contains(start) {
            return order;
        }

        let mut seen: HashSet<N> = HashSet::new();
        let mut queue: VecDeque<N> = VecDeque::new();

        seen.insert(start.clone());
        queue.push_back(start.clone());

        while let Some(node) = queue.pop_front() {
            order.push(node.clone());
            for (next, _) in self.neighbours(&node) {
                if seen.insert(next.clone()) {
                    queue.push_back(next.clone());
                }
            }
        }
        order
    }

    /// Depth-first order, iteratively so a deep graph cannot blow the stack.
    pub fn depth_first(&self, start: &N) -> Vec<N> {
        let mut order = Vec::new();
        if !self.contains(start) {
            return order;
        }

        let mut seen: HashSet<N> = HashSet::new();
        let mut stack: Vec<N> = vec![start.clone()];

        while let Some(node) = stack.pop() {
            if !seen.insert(node.clone()) {
                continue;
            }
            order.push(node.clone());

            // Pushed in reverse so the first neighbour is visited first.
            for (next, _) in self.neighbours(&node).iter().rev() {
                if !seen.contains(next) {
                    stack.push(next.clone());
                }
            }
        }
        order
    }

    /// The shortest path by hop count, or None if there is none.
    pub fn shortest_hops(&self, from: &N, to: &N) -> Option<Vec<N>> {
        if !self.contains(from) || !self.contains(to) {
            return None;
        }

        let mut came_from: HashMap<N, N> = HashMap::new();
        let mut seen: HashSet<N> = HashSet::new();
        let mut queue: VecDeque<N> = VecDeque::new();

        seen.insert(from.clone());
        queue.push_back(from.clone());

        while let Some(node) = queue.pop_front() {
            if node == *to {
                return Some(rebuild(&came_from, from, to));
            }
            for (next, _) in self.neighbours(&node) {
                if seen.insert(next.clone()) {
                    came_from.insert(next.clone(), node.clone());
                    queue.push_back(next.clone());
                }
            }
        }
        None
    }

    /// Dijkstra from one node to every other it can reach.
    pub fn shortest_paths(&self, from: &N) -> ShortestPaths<N> {
        let mut best: HashMap<N, Weight> = HashMap::new();
        let mut came_from: HashMap<N, N> = HashMap::new();
        let mut settled: HashSet<N> = HashSet::new();

        // Reverse turns the max-heap the standard library provides into the
        // min-heap the algorithm wants, without an Ord implementation whose
        // only job is to be backwards.
        let mut frontier: BinaryHeap<Reverse<(Weight, N)>> = BinaryHeap::new();

        if self.contains(from) {
            best.insert(from.clone(), 0);
            frontier.push(Reverse((0, from.clone())));
        }

        while let Some(Reverse((cost, node))) = frontier.pop() {
            if !settled.insert(node.clone()) {
                continue; // a stale entry left behind by a better route
            }

            for (next, weight) in self.neighbours(&node) {
                let candidate = cost + weight;
                let improved = match best.get(next) {
                    Some(current) => candidate < *current,
                    None => true,
                };
                if improved {
                    best.insert(next.clone(), candidate);
                    came_from.insert(next.clone(), node.clone());
                    frontier.push(Reverse((candidate, next.clone())));
                }
            }
        }

        ShortestPaths { source: from.clone(), cost: best, came_from }
    }

    // -------------------------------------------------------- ordering

    /// A topological order, or the cycle that prevents one.
    pub fn topological_order(&self) -> Result<Vec<N>, Cycle<N>> {
        let mut incoming = self.in_degrees();
        let mut ready: BTreeSet<N> = incoming
            .iter()
            .filter(|(_, degree)| **degree == 0)
            .map(|(node, _)| node.clone())
            .collect();

        let mut order = Vec::with_capacity(self.node_count());

        while let Some(node) = ready.iter().next().cloned() {
            ready.remove(&node);
            order.push(node.clone());

            for (next, _) in self.neighbours(&node) {
                if let Some(degree) = incoming.get_mut(next) {
                    *degree -= 1;
                    if *degree == 0 {
                        ready.insert(next.clone());
                    }
                }
            }
        }

        if order.len() == self.node_count() {
            Ok(order)
        } else {
            Err(Cycle { nodes: self.find_cycle().unwrap_or_default() })
        }
    }

    /// One cycle, if the graph has any. Depth-first with a colouring, which
    /// finds a back edge and then walks the current path to name the loop.
    pub fn find_cycle(&self) -> Option<Vec<N>> {
        let mut marks: HashMap<N, MarkKind> = HashMap::new();
        let mut path: Vec<N> = Vec::new();

        for start in self.nodes() {
            if marks.contains_key(start) {
                continue;
            }
            if let Some(cycle) = self.walk(start, &mut marks, &mut path) {
                return Some(cycle);
            }
        }
        None
    }

    fn walk(
        &self,
        node: &N,
        marks: &mut HashMap<N, MarkKind>,
        path: &mut Vec<N>,
    ) -> Option<Vec<N>> {
        marks.insert(node.clone(), MarkKind::Open);
        path.push(node.clone());

        for (next, _) in self.neighbours(node) {
            match marks.get(next) {
                Some(MarkKind::Open) => {
                    // A back edge: the cycle is the tail of the current path.
                    let start = path.iter().position(|n| n == next).unwrap_or(0);
                    let mut cycle: Vec<N> = path[start..].to_vec();
                    cycle.push(next.clone());
                    return Some(cycle);
                }
                Some(MarkKind::Closed) => {}
                None => {
                    if let Some(cycle) = self.walk(next, marks, path) {
                        return Some(cycle);
                    }
                }
            }
        }

        path.pop();
        marks.insert(node.clone(), MarkKind::Closed);
        None
    }

    // ----------------------------------------------------- components

    /// Strongly connected components by Tarjan's algorithm, written with an
    /// explicit stack so that a large graph cannot exhaust the call stack.
    pub fn strongly_connected(&self) -> Vec<Vec<N>> {
        let nodes: Vec<N> = self.nodes().cloned().collect();
        let index_of: HashMap<N, usize> = nodes
            .iter()
            .enumerate()
            .map(|(index, node)| (node.clone(), index))
            .collect();

        let count = nodes.len();
        let mut order: Vec<Option<usize>> = vec![None; count];
        let mut low: Vec<usize> = vec![0; count];
        let mut on_stack = vec![false; count];
        let mut stack: Vec<usize> = Vec::new();
        let mut next_index = 0usize;
        let mut components: Vec<Vec<N>> = Vec::new();

        // (node, how many of its neighbours have been dealt with)
        let mut work: Vec<(usize, usize)> = Vec::new();

        for start in 0..count {
            if order[start].is_some() {
                continue;
            }
            work.push((start, 0));

            while let Some((current, position)) = work.pop() {
                if position == 0 {
                    order[current] = Some(next_index);
                    low[current] = next_index;
                    next_index += 1;
                    stack.push(current);
                    on_stack[current] = true;
                }

                let neighbours = self.neighbours(&nodes[current]);

                if position < neighbours.len() {
                    // Come back to this node after the child is finished.
                    work.push((current, position + 1));
                    let child = index_of[&neighbours[position].0];

                    match order[child] {
                        None => work.push((child, 0)),
                        Some(child_order) => {
                            if on_stack[child] {
                                low[current] = low[current].min(child_order);
                            }
                        }
                    }
                    continue;
                }

                // Every neighbour is done: fold the children's lows in.
                for (to, _) in neighbours {
                    let child = index_of[to];
                    if on_stack[child] {
                        low[current] = low[current].min(low[child]);
                    }
                }

                if Some(low[current]) == order[current] {
                    let mut component = Vec::new();
                    while let Some(member) = stack.pop() {
                        on_stack[member] = false;
                        component.push(nodes[member].clone());
                        if member == current {
                            break;
                        }
                    }
                    component.sort();
                    components.push(component);
                }
            }
        }

        components.sort();
        components
    }

    /// Connected components of the undirected view: direction ignored.
    pub fn connected_components(&self) -> Vec<Vec<N>> {
        let mut undirected: BTreeMap<N, BTreeSet<N>> = BTreeMap::new();
        for node in self.nodes() {
            undirected.entry(node.clone()).or_default();
        }
        for edge in self.edges() {
            undirected.entry(edge.from.clone()).or_default().insert(edge.to.clone());
            undirected.entry(edge.to).or_default().insert(edge.from);
        }

        let mut seen: HashSet<N> = HashSet::new();
        let mut components = Vec::new();

        for start in undirected.keys() {
            if seen.contains(start) {
                continue;
            }

            let mut component = Vec::new();
            let mut queue = VecDeque::from(vec![start.clone()]);
            seen.insert(start.clone());

            while let Some(node) = queue.pop_front() {
                component.push(node.clone());
                if let Some(neighbours) = undirected.get(&node) {
                    for next in neighbours {
                        if seen.insert(next.clone()) {
                            queue.push_back(next.clone());
                        }
                    }
                }
            }

            component.sort();
            components.push(component);
        }

        components
    }

    /// A minimum spanning forest by Kruskal, treating the graph as
    /// undirected. Returns the chosen edges and their total weight.
    pub fn minimum_spanning_forest(&self) -> (Vec<Edge<N>>, Weight) {
        let mut candidates: Vec<Edge<N>> = Vec::new();
        let mut seen_pairs: HashSet<(N, N)> = HashSet::new();

        for edge in self.edges() {
            // Normalise so a-b and b-a are the same undirected edge.
            let key = if edge.from <= edge.to {
                (edge.from.clone(), edge.to.clone())
            } else {
                (edge.to.clone(), edge.from.clone())
            };
            if seen_pairs.insert(key) {
                candidates.push(edge);
            }
        }

        candidates.sort_by(|a, b| {
            a.weight
                .cmp(&b.weight)
                .then_with(|| a.from.cmp(&b.from))
                .then_with(|| a.to.cmp(&b.to))
        });

        let nodes: Vec<N> = self.nodes().cloned().collect();
        let index_of: HashMap<N, usize> = nodes
            .iter()
            .enumerate()
            .map(|(index, node)| (node.clone(), index))
            .collect();

        let mut sets = DisjointSets::new(nodes.len());
        let mut chosen = Vec::new();
        let mut total = 0;

        for edge in candidates {
            let a = index_of[&edge.from];
            let b = index_of[&edge.to];
            if sets.union(a, b) {
                total += edge.weight;
                chosen.push(edge);
            }
        }

        (chosen, total)
    }
}

/// The two states a node can be in during cycle detection.
#[derive(Clone, Copy, PartialEq, Eq)]
enum MarkKind {
    Open,
    Closed,
}

/// Walk a came-from map backwards to produce a path.
fn rebuild<N: Node>(came_from: &HashMap<N, N>, from: &N, to: &N) -> Vec<N> {
    let mut path = vec![to.clone()];
    let mut current = to.clone();

    while current != *from {
        match came_from.get(&current) {
            Some(previous) => {
                path.push(previous.clone());
                current = previous.clone();
            }
            None => break,
        }
    }

    path.reverse();
    path
}

// -------------------------------------------------------------- the results

/// The answer Dijkstra gives: a cost to every reachable node, and enough
/// information to reconstruct the route to any of them.
#[derive(Debug, Clone)]
pub struct ShortestPaths<N: Node> {
    source: N,
    cost: HashMap<N, Weight>,
    came_from: HashMap<N, N>,
}

impl<N: Node> ShortestPaths<N> {
    pub fn source(&self) -> &N {
        &self.source
    }

    pub fn cost_to(&self, node: &N) -> Option<Weight> {
        self.cost.get(node).copied()
    }

    pub fn route_to(&self, node: &N) -> Option<Vec<N>> {
        if !self.cost.contains_key(node) {
            return None;
        }
        Some(rebuild(&self.came_from, &self.source, node))
    }

    /// Every reachable node with its cost, cheapest first.
    pub fn reachable(&self) -> Vec<(N, Weight)> {
        let mut out: Vec<(N, Weight)> = self
            .cost
            .iter()
            .map(|(node, weight)| (node.clone(), *weight))
            .collect();
        out.sort_by(|a, b| a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0)));
        out
    }

    pub fn furthest(&self) -> Option<(N, Weight)> {
        self.reachable().into_iter().max_by_key(|(_, weight)| *weight)
    }
}

/// The cycle that stops a graph being ordered.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Cycle<N: Node> {
    pub nodes: Vec<N>,
}

impl<N: Node> Display for Cycle<N> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let names: Vec<String> = self.nodes.iter().map(N::to_string).collect();
        write!(f, "cycle: {}", names.join(" -> "))
    }
}

impl<N: Node> std::error::Error for Cycle<N> {}

// ----------------------------------------------------------- union-find

/// Disjoint sets with path compression and union by rank. The whole of
/// Kruskal's efficiency lives in here.
struct DisjointSets {
    parent: Vec<usize>,
    rank: Vec<u8>,
}

impl DisjointSets {
    fn new(size: usize) -> Self {
        DisjointSets { parent: (0..size).collect(), rank: vec![0; size] }
    }

    fn find(&mut self, mut node: usize) -> usize {
        while self.parent[node] != node {
            // Halve the path on the way up, which is as good as full
            // compression and needs no second pass.
            self.parent[node] = self.parent[self.parent[node]];
            node = self.parent[node];
        }
        node
    }

    /// Join two sets. Returns false when they were already the same set,
    /// which is exactly the "this edge would make a cycle" test.
    fn union(&mut self, a: usize, b: usize) -> bool {
        let (mut root_a, mut root_b) = (self.find(a), self.find(b));
        if root_a == root_b {
            return false;
        }
        if self.rank[root_a] < self.rank[root_b] {
            std::mem::swap(&mut root_a, &mut root_b);
        }
        self.parent[root_b] = root_a;
        if self.rank[root_a] == self.rank[root_b] {
            self.rank[root_a] += 1;
        }
        true
    }
}

// -------------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Graph<&'static str> {
        Graph::from_edges(vec![
            ("a", "b", 4),
            ("a", "c", 2),
            ("b", "d", 5),
            ("c", "b", 1),
            ("c", "d", 8),
            ("d", "e", 3),
        ])
    }

    #[test]
    fn counts_nodes_and_edges() {
        let graph = sample();
        assert_eq!(graph.node_count(), 5);
        assert_eq!(graph.edge_count(), 6);
    }

    #[test]
    fn breadth_first_visits_by_hops() {
        assert_eq!(sample().breadth_first(&"a"), vec!["a", "b", "c", "d", "e"]);
    }

    #[test]
    fn dijkstra_prefers_the_cheap_detour() {
        let paths = sample().shortest_paths(&"a");
        // a->b directly costs 4; a->c->b costs 3.
        assert_eq!(paths.cost_to(&"b"), Some(3));
        assert_eq!(paths.route_to(&"b"), Some(vec!["a", "c", "b"]));
        assert_eq!(paths.cost_to(&"e"), Some(11));
    }

    #[test]
    fn hops_ignore_weight() {
        let path = sample().shortest_hops(&"a", &"d").unwrap();
        assert_eq!(path.len(), 3);
        assert_eq!(path.first(), Some(&"a"));
        assert_eq!(path.last(), Some(&"d"));
    }

    #[test]
    fn unreachable_nodes_have_no_cost() {
        let mut graph = sample();
        graph.add_node("island");
        let paths = graph.shortest_paths(&"a");
        assert_eq!(paths.cost_to(&"island"), None);
        assert_eq!(paths.route_to(&"island"), None);
    }

    #[test]
    fn topological_order_respects_edges() {
        let order = sample().topological_order().expect("acyclic");
        let position = |name: &str| order.iter().position(|n| *n == name).unwrap();
        assert!(position("a") < position("c"));
        assert!(position("c") < position("b"));
        assert!(position("d") < position("e"));
    }

    #[test]
    fn a_cycle_is_reported() {
        let graph: Graph<&str> =
            Graph::from_edges(vec![("x", "y", 1), ("y", "z", 1), ("z", "x", 1)]);
        let error = graph.topological_order().unwrap_err();
        assert_eq!(error.nodes.len(), 4); // three nodes, first repeated
        assert_eq!(error.nodes.first(), error.nodes.last());
    }

    #[test]
    fn strongly_connected_components() {
        let graph: Graph<&str> = Graph::from_edges(vec![
            ("a", "b", 1),
            ("b", "c", 1),
            ("c", "a", 1),
            ("c", "d", 1),
            ("d", "e", 1),
            ("e", "d", 1),
        ]);
        let components = graph.strongly_connected();
        assert_eq!(components.len(), 2);
        assert!(components.contains(&vec!["a", "b", "c"]));
        assert!(components.contains(&vec!["d", "e"]));
    }

    #[test]
    fn spanning_forest_skips_cycles() {
        let mut graph: Graph<&str> = Graph::new();
        graph.add_undirected("a", "b", 1);
        graph.add_undirected("b", "c", 2);
        graph.add_undirected("a", "c", 9);
        graph.add_undirected("d", "e", 4);

        let (edges, total) = graph.minimum_spanning_forest();
        assert_eq!(edges.len(), 3); // two trees over five nodes
        assert_eq!(total, 7);
    }

    #[test]
    fn connected_components_ignore_direction() {
        let graph: Graph<&str> =
            Graph::from_edges(vec![("a", "b", 1), ("c", "d", 1)]);
        assert_eq!(graph.connected_components(), vec![vec!["a", "b"], vec!["c", "d"]]);
    }

    #[test]
    fn reversing_turns_every_edge_round() {
        let reversed = sample().reversed();
        assert_eq!(reversed.node_count(), 5);
        assert_eq!(reversed.edge_count(), 6);
        assert!(reversed.neighbours(&"e").is_empty());
        assert_eq!(reversed.neighbours(&"b").len(), 1);
    }
}

// --------------------------------------------------------------------- main

/// The ferry network, as a weighted directed graph of crossing times.
fn ferry_network() -> Graph<String> {
    let edges: Vec<(&str, &str, Weight)> = vec![
        ("Fenwick Quay", "Marlow Street", 19),
        ("Marlow Street", "Fenwick Quay", 19),
        ("Fenwick Quay", "Kestrel Point", 26),
        ("Kestrel Point", "Fenwick Quay", 26),
        ("Marlow Street", "Halloway Bank", 34),
        ("Halloway Bank", "Marlow Street", 34),
        ("Fenwick Quay", "North Landing", 42),
        ("North Landing", "Fenwick Quay", 42),
        ("Kestrel Point", "North Landing", 21),
        ("North Landing", "Kestrel Point", 21),
        ("Halloway Bank", "Cooper Reach", 15),
        ("Cooper Reach", "Halloway Bank", 15),
        ("Tern Island", "Gull Rock", 12),
        ("Gull Rock", "Tern Island", 12),
    ];

    Graph::from_edges(
        edges
            .into_iter()
            .map(|(a, b, w)| (a.to_string(), b.to_string(), w)),
    )
}

/// A build pipeline, as a directed acyclic graph of tasks.
fn pipeline() -> Graph<&'static str> {
    Graph::from_edges(vec![
        ("checkout", "restore", 1),
        ("restore", "compile", 1),
        ("compile", "unit-tests", 1),
        ("compile", "lint", 1),
        ("compile", "package", 1),
        ("unit-tests", "integration-tests", 1),
        ("lint", "publish", 1),
        ("package", "publish", 1),
        ("integration-tests", "publish", 1),
        ("publish", "announce", 1),
    ])
}

fn main() {
    let network = ferry_network();

    println!("--- the network ---");
    println!(
        "  {} terminal(s), {} directed crossing(s)",
        network.node_count(),
        network.edge_count()
    );
    for node in network.nodes() {
        let out: Vec<String> = network
            .neighbours(node)
            .iter()
            .map(|(to, weight)| format!("{to} ({weight}m)"))
            .collect();
        println!("  {node:<14} -> {}", out.join(", "));
    }

    println!("\n--- breadth first from Fenwick Quay ---");
    println!("  {}", network.breadth_first(&"Fenwick Quay".to_string()).join(", "));

    println!("\n--- depth first from Fenwick Quay ---");
    println!("  {}", network.depth_first(&"Fenwick Quay".to_string()).join(", "));

    println!("\n--- shortest crossings from Fenwick Quay ---");
    let paths = network.shortest_paths(&"Fenwick Quay".to_string());
    for (node, cost) in paths.reachable() {
        let route = paths.route_to(&node).unwrap_or_default();
        println!("  {node:<14} {cost:>3}m   {}", route.join(" -> "));
    }
    if let Some((node, cost)) = paths.furthest() {
        println!("  furthest: {node} at {cost} minutes");
    }

    println!("\n--- the quickest route beats the fewest hops ---");
    let from = "Fenwick Quay".to_string();
    let to = "Cooper Reach".to_string();
    let hops = network.shortest_hops(&from, &to).unwrap_or_default();
    let quickest = paths.route_to(&to).unwrap_or_default();
    println!(
        "  fewest hops: {} ({} legs)",
        hops.join(" -> "),
        hops.len().saturating_sub(1)
    );
    println!(
        "  quickest:    {} ({} minutes)",
        quickest.join(" -> "),
        paths.cost_to(&to).unwrap_or(0)
    );

    println!("\n--- islands ---");
    for component in network.connected_components() {
        println!("  {}", component.join(", "));
    }
    println!("  Tern Island and Gull Rock are not reachable from the mainland.");

    println!("\n--- a minimum spanning forest ---");
    let (chosen, total) = network.minimum_spanning_forest();
    for edge in &chosen {
        println!("  {edge}");
    }
    println!("  {} crossing(s), {} minutes in total", chosen.len(), total);

    println!("\n--- a build pipeline ---");
    let build = pipeline();
    match build.topological_order() {
        Ok(order) => {
            for (step, task) in order.iter().enumerate() {
                println!("  {:>2}. {task}", step + 1);
            }
        }
        Err(cycle) => println!("  {cycle}"),
    }

    println!("\n--- adding an edge that closes a loop ---");
    let mut broken = pipeline();
    broken.add_edge("announce", "restore", 1);
    match broken.topological_order() {
        Ok(_) => println!("  unexpectedly ordered"),
        Err(cycle) => println!("  {cycle}"),
    }

    println!("\n--- strongly connected components of the broken pipeline ---");
    for component in broken.strongly_connected() {
        if component.len() > 1 {
            println!("  mutually reachable: {}", component.join(", "));
        }
    }

    println!("\n--- in-degrees ---");
    for (task, degree) in build.in_degrees() {
        println!("  {task:<20} {degree}");
    }
}

#!/usr/bin/env ruby
# frozen_string_literal: true

# A dependency resolver: semantic versions, constraint parsing, backtracking
# resolution, cycle detection, and a topological install order.
#
# Given a registry of packages and a set of requirements, it answers three
# questions:
#
#   1. Is there a set of versions that satisfies every constraint?
#   2. If not, which two requirements are irreconcilable?
#   3. If so, in what order must they be installed?
#
# Run it to resolve the built-in example registry:
#
#   ruby dependency_resolver.rb
#   ruby dependency_resolver.rb --explain
#
# The registry is invented. No package named here exists.

require 'set'

# --------------------------------------------------------------------- errors

class ResolutionError < StandardError; end

class ConflictError < ResolutionError
  attr_reader :package, :constraints

  def initialize(package, constraints)
    @package = package
    @constraints = constraints
    listed = constraints.map { |source, range| "#{source} wants #{range}" }.join('; ')
    super("no version of #{package} satisfies every requirement: #{listed}")
  end
end

class CircularDependencyError < ResolutionError
  attr_reader :cycle

  def initialize(cycle)
    @cycle = cycle
    super("circular dependency: #{cycle.join(' -> ')}")
  end
end

# -------------------------------------------------------------------- version

# A semantic version. Comparable, so sorting and range checks come free.
class Version
  include Comparable

  PATTERN = /\A(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?\z/

  attr_reader :major, :minor, :patch, :prerelease, :build

  def self.parse(text)
    match = PATTERN.match(text.to_s.strip)
    raise ArgumentError, "not a version: #{text.inspect}" if match.nil?

    new(match[1].to_i, match[2].to_i, match[3].to_i, match[4], match[5])
  end

  def initialize(major, minor, patch, prerelease = nil, build = nil)
    @major = major
    @minor = minor
    @patch = patch
    @prerelease = prerelease
    @build = build
    freeze
  end

  def prerelease? = !@prerelease.nil?

  # Build metadata is ignored in comparisons, as the specification requires.
  def <=>(other)
    return nil unless other.is_a?(Version)

    by_number = [major, minor, patch] <=> [other.major, other.minor, other.patch]
    return by_number unless by_number.zero?

    compare_prerelease(other)
  end

  def eql?(other) = other.is_a?(Version) && (self <=> other)&.zero?

  def hash = [major, minor, patch, prerelease].hash

  def to_s
    base = "#{major}.#{minor}.#{patch}"
    base += "-#{prerelease}" if prerelease
    base += "+#{build}" if build
    base
  end

  private

  # A version with a prerelease tag sorts below the same version without one.
  # Otherwise the tags are compared identifier by identifier: numeric ones
  # numerically, everything else as text, and numeric sorts below textual.
  def compare_prerelease(other)
    return 0 if prerelease.nil? && other.prerelease.nil?
    return 1 if prerelease.nil?
    return -1 if other.prerelease.nil?

    mine = prerelease.split('.')
    theirs = other.prerelease.split('.')

    mine.zip(theirs).each do |a, b|
      return 1 if b.nil?

      result = compare_identifier(a, b)
      return result unless result.zero?
    end

    mine.size <=> theirs.size
  end

  def compare_identifier(a, b)
    a_numeric = a.match?(/\A\d+\z/)
    b_numeric = b.match?(/\A\d+\z/)

    return a.to_i <=> b.to_i if a_numeric && b_numeric
    return -1 if a_numeric
    return 1 if b_numeric

    a <=> b
  end
end

# ------------------------------------------------------------------ constraint

# A version range. Understands the operators a lock file actually uses:
#
#   "1.2.3"     exactly that version
#   ">=1.2.0"   at least
#   "<2.0.0"    below
#   "~>1.4.2"   at least 1.4.2, below 1.5.0
#   "^1.4.2"    at least 1.4.2, below 2.0.0
#   "*"         anything
#
# Several clauses may be combined with commas, and all of them must hold.
class Constraint
  CLAUSE = /\A(>=|<=|>|<|~>|\^|=)?\s*(.+)\z/

  attr_reader :source

  def self.parse(text)
    clauses = text.to_s.split(',').map(&:strip).reject(&:empty?)
    return new([], text) if clauses == ['*'] || clauses.empty?

    new(clauses.map { |clause| parse_clause(clause) }, text)
  end

  def self.parse_clause(clause)
    match = CLAUSE.match(clause)
    raise ArgumentError, "not a constraint: #{clause.inspect}" if match.nil?

    operator = match[1] || '='
    version = Version.parse(match[2])

    case operator
    when '~>' then [[:>=, version], [:<, bump_minor(version)]]
    when '^' then [[:>=, version], [:<, bump_major(version)]]
    else [[operator.to_sym, version]]
    end
  end

  def self.bump_minor(version) = Version.new(version.major, version.minor + 1, 0)

  def self.bump_major(version) = Version.new(version.major + 1, 0, 0)

  def initialize(tests, source)
    @tests = tests.flatten(1)
    @source = source
    freeze
  end

  def satisfied_by?(version)
    # A prerelease is never matched unless the constraint mentions one, which
    # is the rule everybody forgets and then rediscovers in production.
    return false if version.prerelease? && !mentions_prerelease?

    @tests.all? { |operator, bound| compare(version, operator, bound) }
  end

  def to_s = @source.to_s

  private

  def mentions_prerelease? = @tests.any? { |_, bound| bound.prerelease? }

  def compare(version, operator, bound)
    case operator
    when :>= then version >= bound
    when :<= then version <= bound
    when :> then version > bound
    when :< then version < bound
    when :'=' then version == bound
    else raise ArgumentError, "unknown operator: #{operator}"
    end
  end
end

# --------------------------------------------------------------------- package

Release = Struct.new(:name, :version, :dependencies) do
  def to_s = "#{name} #{version}"
end

# A registry: every package, every published version, and what each depends on.
class Registry
  def initialize
    @releases = Hash.new { |hash, key| hash[key] = [] }
  end

  def publish(name, version, dependencies = {})
    parsed = dependencies.transform_values { |range| Constraint.parse(range) }
    @releases[name] << Release.new(name, Version.parse(version), parsed)
    @releases[name].sort_by!(&:version)
    self
  end

  def known?(name) = @releases.key?(name)

  def names = @releases.keys.sort

  # Newest first: the resolver tries the highest version that fits, and only
  # backtracks to older ones when the newest leads nowhere.
  def candidates(name, constraint)
    @releases[name].reverse.select { |release| constraint.satisfied_by?(release.version) }
  end

  def all(name) = @releases[name]
end

# -------------------------------------------------------------------- resolver

# Backtracking resolution. The search is depth-first over packages, newest
# version first, and it records the reason every candidate was rejected so
# that a failure can be explained rather than merely reported.
class Resolver
  Attempt = Struct.new(:package, :version, :outcome, :detail)

  attr_reader :log

  def initialize(registry, explain: false)
    @registry = registry
    @explain = explain
    @log = []
    @deepest_conflict = nil
  end

  def resolve(requirements)
    constraints = Hash.new { |hash, key| hash[key] = [] }
    requirements.each do |name, range|
      constraints[name] << ['root', Constraint.parse(range)]
    end

    solution = search(constraints, {})
    raise ConflictError.new(*blame(constraints)) if solution.nil?

    order(solution)
  end

  private

  def note(package, version, outcome, detail = nil)
    @log << Attempt.new(package, version, outcome, detail) if @explain
  end

  def search(constraints, chosen)
    pending = constraints.keys.reject { |name| chosen.key?(name) }
    return chosen if pending.empty?

    # Most-constrained package first: it fails soonest, which prunes most.
    package = pending.min_by { |name| @registry.candidates(name, merge(constraints[name])).size }

    unless @registry.known?(package)
      note(package, nil, :unknown)
      return nil
    end

    combined = merge(constraints[package])

    @registry.candidates(package, combined).each do |release|
      next_constraints = deep_copy(constraints)
      conflict = false

      release.dependencies.each do |name, range|
        next_constraints[name] << ["#{package} #{release.version}", range]
        if @registry.known?(name) && @registry.candidates(name, merge(next_constraints[name])).empty?
          note(package, release.version, :rejected, "no #{name} satisfies #{range}")
          record_conflict(name, next_constraints[name])
          conflict = true
          break
        end
      end
      next if conflict

      note(package, release.version, :trying)
      result = search(next_constraints, chosen.merge(package => release))
      return result unless result.nil?

      note(package, release.version, :backtracked)
    end

    nil
  end

  # Several constraints on one package collapse into one that requires all.
  def merge(pairs)
    Constraint.parse(pairs.map { |_, constraint| constraint.to_s }.join(','))
  end

  def deep_copy(constraints)
    copy = Hash.new { |hash, key| hash[key] = [] }
    constraints.each { |name, pairs| copy[name] = pairs.dup }
    copy
  end

  # Remember the narrowest dead end the search reached. A conflict is usually
  # invisible in the root requirements — it only appears once two branches
  # have each added a constraint on the same package — so the message has to
  # come from where the search actually stopped, not from the root.
  def record_conflict(package, pairs)
    return if @deepest_conflict && @deepest_conflict.last.size >= pairs.size

    @deepest_conflict = [package, pairs.dup]
  end

  # Find the package whose constraints cannot all hold, for the error message.
  def blame(constraints)
    unknown = constraints.keys.find { |name| !@registry.known?(name) }
    return [unknown, constraints[unknown].map { |source, c| [source, c.to_s] }] if unknown

    constraints.each do |name, pairs|
      next unless @registry.candidates(name, merge(pairs)).empty?

      return [name, pairs.map { |source, c| [source, c.to_s] }]
    end

    if @deepest_conflict
      name, pairs = @deepest_conflict
      return [name, pairs.map { |source, c| [source, c.to_s] }]
    end

    [constraints.keys.first, [['root', 'any version']]]
  end

  # Kahn's algorithm, with the remaining nodes reported as a cycle if the
  # queue empties early.
  def order(solution)
    incoming = solution.keys.to_h { |name| [name, 0] }
    outgoing = Hash.new { |hash, key| hash[key] = [] }

    solution.each do |name, release|
      release.dependencies.each_key do |dependency|
        next unless solution.key?(dependency)

        outgoing[dependency] << name
        incoming[name] += 1
      end
    end

    ready = incoming.select { |_, count| count.zero? }.keys.sort
    sorted = []

    until ready.empty?
      name = ready.shift
      sorted << solution[name]
      outgoing[name].sort.each do |dependent|
        incoming[dependent] -= 1
        ready << dependent if incoming[dependent].zero?
      end
      ready.sort!
    end

    raise CircularDependencyError, find_cycle(solution) if sorted.size != solution.size

    sorted
  end

  def find_cycle(solution)
    visiting = Set.new
    path = []
    cycle = nil

    visit = lambda do |name|
      return true if cycle

      if visiting.include?(name)
        cycle = path[path.index(name)..] + [name]
        return true
      end

      visiting << name
      path.push(name)
      solution[name].dependencies.each_key do |dependency|
        visit.call(dependency) if solution.key?(dependency)
      end
      path.pop
      visiting.delete(name)
      false
    end

    solution.each_key { |name| visit.call(name) }
    cycle || solution.keys
  end
end

# ------------------------------------------------------------------- built-in

def example_registry
  registry = Registry.new

  registry.publish('driftwood', '3.0.0', 'tideline' => '^2.0.0', 'kestrel' => '~>1.4.0')
  registry.publish('driftwood', '2.4.1', 'tideline' => '^1.6.0', 'kestrel' => '~>1.2.0')
  registry.publish('driftwood', '2.3.0', 'tideline' => '^1.4.0')

  registry.publish('tideline', '2.1.0', 'halloway' => '>=0.9.0')
  registry.publish('tideline', '2.0.0', 'halloway' => '>=0.9.0')
  registry.publish('tideline', '1.8.2', 'halloway' => '>=0.7.0, <1.0.0')
  registry.publish('tideline', '1.6.0', 'halloway' => '>=0.7.0, <1.0.0')
  registry.publish('tideline', '1.4.0')

  registry.publish('kestrel', '1.4.3', 'halloway' => '^0.9.0')
  registry.publish('kestrel', '1.4.0', 'halloway' => '^0.9.0')
  registry.publish('kestrel', '1.2.5', 'halloway' => '>=0.7.0')
  registry.publish('kestrel', '1.2.0')

  registry.publish('halloway', '1.0.0-rc.1')
  registry.publish('halloway', '0.9.4')
  registry.publish('halloway', '0.9.0')
  registry.publish('halloway', '0.7.1')

  registry
end

def report(title, registry, requirements, explain:)
  puts title
  puts '-' * title.length

  resolver = Resolver.new(registry, explain: explain)
  begin
    plan = resolver.resolve(requirements)
    width = plan.map { |release| release.name.length }.max
    plan.each_with_index do |release, index|
      puts format('  %d. %-*s %s', index + 1, width, release.name, release.version)
    end
  rescue ResolutionError => error
    puts "  unresolved: #{error.message}"
  end

  if explain && !resolver.log.empty?
    puts '  attempts:'
    resolver.log.each do |attempt|
      version = attempt.version ? " #{attempt.version}" : ''
      detail = attempt.detail ? " (#{attempt.detail})" : ''
      puts format('    %-12s %s%s%s', attempt.outcome, attempt.package, version, detail)
    end
  end

  puts
end

if __FILE__ == $PROGRAM_NAME
  explain = ARGV.include?('--explain')
  registry = example_registry

  report('Resolving driftwood ^2.0.0', registry,
         { 'driftwood' => '^2.0.0' }, explain: explain)

  report('Resolving driftwood ^3.0.0', registry,
         { 'driftwood' => '^3.0.0' }, explain: explain)

  report('Resolving driftwood ^2.0.0 with halloway pinned to 0.7.1', registry,
         { 'driftwood' => '^2.0.0', 'halloway' => '0.7.1' }, explain: explain)

  report('Resolving driftwood ^3.0.0 with halloway pinned to 0.7.1', registry,
         { 'driftwood' => '^3.0.0', 'halloway' => '0.7.1' }, explain: explain)

  report('Resolving a package that does not exist', registry,
         { 'marlow' => '*' }, explain: false)

  puts 'Prerelease ordering:'
  versions = %w[1.0.0 1.0.0-rc.1 1.0.0-beta.11 1.0.0-beta.2 1.0.0-alpha 0.9.4]
             .map { |text| Version.parse(text) }
  puts "  #{versions.sort.map(&:to_s).join(' < ')}"
  puts

  puts 'Constraint matching:'
  [['~>1.4.2', %w[1.4.1 1.4.2 1.4.9 1.5.0]],
   ['^1.4.2', %w[1.4.1 1.4.2 1.9.9 2.0.0]],
   ['>=0.7.0, <1.0.0', %w[0.6.9 0.7.0 0.9.4 1.0.0]]].each do |range, samples|
    constraint = Constraint.parse(range)
    results = samples.map do |text|
      "#{text}#{constraint.satisfied_by?(Version.parse(text)) ? ' yes' : ' no'}"
    end
    puts format('  %-16s %s', range, results.join(', '))
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

# A small text adventure engine: world definition, a two-word command parser,
# an inventory, locked doors, and a win condition.
#
# Run it and type commands:
#
#   ruby text_adventure.rb
#   > look
#   > take brass key
#   > north
#   > unlock door with brass key
#
# Everything below is one file and uses only the standard library. The setting
# is invented.

require 'set'

# ---------------------------------------------------------------- world model

# A thing that can be picked up, examined, or used on something else.
class Item
  attr_reader :name, :aliases, :description
  attr_accessor :portable

  def initialize(name, description, aliases: [], portable: true)
    @name = name
    @description = description
    @aliases = Set.new([name.downcase] + aliases.map(&:downcase))
    @portable = portable
  end

  def matches?(word)
    @aliases.include?(word.downcase)
  end

  def to_s = @name
end

# A room, its exits, and whatever is lying on the floor of it.
class Room
  attr_reader :key, :title, :items
  attr_accessor :description, :visited

  def initialize(key, title, description)
    @key = key
    @title = title
    @description = description
    @exits = {}
    @items = []
    @visited = false
  end

  def connect(direction, room_key, locked_by: nil)
    @exits[direction.to_sym] = { to: room_key, locked_by: locked_by, open: locked_by.nil? }
    self
  end

  def exit_for(direction)
    @exits[direction.to_sym]
  end

  def exits = @exits

  def open_directions
    @exits.select { |_, e| e[:open] }.keys
  end

  def add(item)
    @items << item
    self
  end

  def take(word)
    index = @items.index { |item| item.matches?(word) }
    index ? @items.delete_at(index) : nil
  end

  def find(word)
    @items.find { |item| item.matches?(word) }
  end
end

# The player: where they are, what they carry, and what they have done.
class Player
  attr_accessor :location
  attr_reader :carrying, :moves, :flags

  MAX_CARRIED = 6

  def initialize(location)
    @location = location
    @carrying = []
    @moves = 0
    @flags = Set.new
  end

  def carrying?(word)
    @carrying.any? { |item| item.matches?(word) }
  end

  def held(word)
    @carrying.find { |item| item.matches?(word) }
  end

  def take(item)
    return :full if @carrying.size >= MAX_CARRIED

    @carrying << item
    :ok
  end

  def drop(word)
    index = @carrying.index { |item| item.matches?(word) }
    index ? @carrying.delete_at(index) : nil
  end

  def moved! = @moves += 1
end

# ------------------------------------------------------------------ the world

# Builds the map. Kept separate from the engine so the engine has no
# knowledge of this particular story.
module World
  DIRECTIONS = {
    'north' => :north, 'n' => :north,
    'south' => :south, 's' => :south,
    'east' => :east,   'e' => :east,
    'west' => :west,   'w' => :west,
    'up' => :up,       'u' => :up,
    'down' => :down,   'd' => :down
  }.freeze

  OPPOSITE = {
    north: :south, south: :north,
    east: :west, west: :east,
    up: :down, down: :up
  }.freeze

  def self.build
    rooms = {}

    rooms[:jetty] = Room.new(:jetty, 'The Jetty', <<~TEXT.strip)
      Fog sits on the water so thickly that the far bank is a rumour. A wooden
      jetty runs north to a boathouse. A rowing boat is tied here, low in the
      water and going nowhere without oars.
    TEXT

    rooms[:boathouse] = Room.new(:boathouse, 'The Boathouse', <<~TEXT.strip)
      Rope, tar, and forty years of damp. Racks along the west wall hold
      nothing but their own dust. A door in the north wall is shut, and its
      lock is newer than anything else in the building.
    TEXT

    rooms[:office] = Room.new(:office, "The Harbourmaster's Office", <<~TEXT.strip)
      A desk, a chair that does not match it, and a wall of pigeonholes
      labelled in a hand nobody living can read. A window looks east onto the
      water. Steps lead down.
    TEXT

    rooms[:cellar] = Room.new(:cellar, 'The Cellar', <<~TEXT.strip)
      Cold, and lower than the tide has any right to let it be. A brass
      lantern bracket is empty on the wall. Something metal glints where the
      floor meets the far corner.
    TEXT

    rooms[:lamp_room] = Room.new(:lamp_room, 'The Lamp Room', <<~TEXT.strip)
      The top of the old light. Glass on every side, and beyond it nothing but
      white. The mechanism is intact. It only wants lighting.
    TEXT

    rooms[:jetty].connect(:north, :boathouse)
    rooms[:boathouse].connect(:south, :jetty)
    rooms[:boathouse].connect(:north, :office, locked_by: 'brass key')
    rooms[:office].connect(:south, :boathouse)
    rooms[:office].connect(:down, :cellar)
    rooms[:cellar].connect(:up, :office)
    rooms[:office].connect(:up, :lamp_room, locked_by: 'iron key')
    rooms[:lamp_room].connect(:down, :office)

    rooms[:jetty].add(Item.new('coil of rope', 'Tarred, stiff, and long enough for something.',
                               aliases: ['rope', 'coil']))
    rooms[:boathouse].add(Item.new('brass key', 'Small, worn smooth, and warm to the touch.',
                                   aliases: ['key', 'brass']))
    rooms[:office].add(Item.new('logbook', <<~TEXT.strip, aliases: ['book', 'log']))
      Times of lighting, four years of them, in a careful hand. The last entry
      is a September, and it stops mid-page. Tucked into the spine is a note:
      "iron key, cellar, behind the bracket."
    TEXT
    rooms[:cellar].add(Item.new('iron key', 'Heavy, cold, and unmistakably for the lamp room.',
                                aliases: ['iron', 'key']))
    rooms[:cellar].add(Item.new('oil can', 'Half full, and it has not leaked in thirty years.',
                                aliases: ['can', 'oil']))
    rooms[:lamp_room].add(Item.new('mechanism', <<~TEXT.strip, aliases: ['lamp', 'light'], portable: false))
      Cast iron and four panes of glass, one cracked in the corner. It wants
      oil, and then it wants a match.
    TEXT
    rooms[:boathouse].add(Item.new('box of matches', 'Dry, which is the only surprising thing here.',
                                   aliases: ['matches', 'match', 'box']))

    rooms
  end
end

# --------------------------------------------------------------- the commands

# One verb, its aliases, and what it does. Registering commands in a table
# keeps the parser from turning into a case statement forty branches long.
Command = Struct.new(:names, :takes_object, :handler)

class Game
  VERSION = '1.0'

  def initialize(output: $stdout, input: $stdin)
    @rooms = World.build
    @player = Player.new(:jetty)
    @out = output
    @in = input
    @running = true
    @won = false
    @commands = build_commands
  end

  def room = @rooms[@player.location]

  # ---------------------------------------------------------------- the loop

  def run
    say banner
    describe(room)

    while @running
      @out.print '> '
      line = @in.gets
      break if line.nil?

      dispatch(line.strip)
      break if @won
    end

    say @won ? "\nYou lit it. #{@player.moves} moves." : "\nGoodbye."
  end

  # --------------------------------------------------------------- despatch

  def dispatch(line)
    return if line.empty?

    words = line.downcase.split(/\s+/)
    verb = words.first

    if World::DIRECTIONS.key?(verb) && words.size == 1
      return go(World::DIRECTIONS[verb])
    end

    command = @commands.find { |c| c.names.include?(verb) }
    return say "I do not know how to #{verb}." if command.nil?

    object = words[1..].join(' ')
    if command.takes_object && object.empty?
      return say "#{verb.capitalize} what?"
    end

    command.handler.call(object)
  end

  private

  def build_commands
    [
      Command.new(%w[look l], false, ->(_) { describe(room, force: true) }),
      Command.new(%w[go walk move], true, ->(o) { go_named(o) }),
      Command.new(%w[take get pick], true, ->(o) { take(o) }),
      Command.new(%w[drop leave], true, ->(o) { drop(o) }),
      Command.new(%w[examine x inspect read], true, ->(o) { examine(o) }),
      Command.new(%w[inventory i inv], false, ->(_) { inventory }),
      Command.new(%w[unlock open], true, ->(o) { unlock(o) }),
      Command.new(%w[oil], true, ->(o) { oil(o) }),
      Command.new(%w[light burn], true, ->(o) { light(o) }),
      Command.new(%w[exits], false, ->(_) { exits }),
      Command.new(%w[help ?], false, ->(_) { say help_text }),
      Command.new(%w[quit exit q], false, ->(_) { @running = false })
    ]
  end

  # ----------------------------------------------------------------- output

  def say(text) = @out.puts(text)

  # "a rope" but "an oil can" — cheap, and right often enough for a sample.
  def article(word)
    %w[a e i o u].include?(word.to_s[0]&.downcase) ? 'an' : 'a'
  end

  def banner
    <<~TEXT
      THE LAMP ROOM  ·  version #{VERSION}
      A very short adventure. Type "help" for the verbs.

    TEXT
  end

  def help_text
    <<~TEXT
      Movement:  north south east west up down (or n s e w u d)
      Things:    take, drop, examine, inventory
      Doors:     unlock <thing> with <key>
      Other:     look, exits, help, quit
    TEXT
  end

  def describe(place, force: false)
    if place.visited && !force
      say "#{place.title}."
    else
      say "\n#{place.title}"
      say place.description
      place.visited = true
    end

    place.items.each { |item| say "  There is #{article(item)} #{item} here." }
  end

  def exits
    open = room.open_directions
    shut = room.exits.reject { |_, e| e[:open] }.keys
    say open.empty? ? 'No way out that you can see.' : "Exits: #{open.join(', ')}."
    say "Also, locked: #{shut.join(', ')}." unless shut.empty?
  end

  # --------------------------------------------------------------- movement

  def go_named(word)
    direction = World::DIRECTIONS[word.split.first.to_s]
    direction ? go(direction) : say("#{word.capitalize} is not a direction.")
  end

  def go(direction)
    passage = room.exit_for(direction)
    return say "You cannot go #{direction} from here." if passage.nil?
    return say "The way #{direction} is locked." unless passage[:open]

    @player.location = passage[:to]
    @player.moved!
    describe(room)
  end

  # ---------------------------------------------------------------- objects

  def take(word)
    item = room.find(word)
    return say "There is no #{word} here." if item.nil?
    return say "The #{item} is not going anywhere." unless item.portable

    case @player.take(item)
    when :full then say 'You are carrying too much already.'
    else
      room.take(word)
      say "Taken: #{item}."
    end
  end

  def drop(word)
    item = @player.drop(word)
    return say "You are not carrying #{article(word)} #{word}." if item.nil?

    room.add(item)
    say "Dropped: #{item}."
  end

  def examine(word)
    item = @player.held(word) || room.find(word)
    return say "You see no #{word} here." if item.nil?

    say item.description
  end

  def inventory
    return say 'You are empty-handed.' if @player.carrying.empty?

    say 'You are carrying:'
    @player.carrying.each { |item| say "  #{item}" }
  end

  # ----------------------------------------------------------------- puzzles

  # "unlock door with brass key" — the object arrives as one string, so the
  # preposition is split out here rather than in the parser.
  def unlock(object)
    target, key_name = object.split(/\s+with\s+/, 2)

    if key_name.nil?
      held_key = @player.carrying.find { |item| item.name.end_with?('key') }
      return say 'Unlock it with what?' if held_key.nil?

      key_name = held_key.name
    end

    return say "You are not carrying #{article(key_name)} #{key_name}." unless @player.carrying?(key_name)

    key = @player.held(key_name)
    passage = room.exits.values.find { |e| !e[:open] && key.matches?(e[:locked_by].split.first) }

    if passage.nil?
      return say "Nothing here is locked by the #{key}." if target.to_s.empty?

      return say "The #{key} does not fit the #{target}."
    end

    passage[:open] = true
    other = @rooms[passage[:to]].exits.values.find { |e| e[:to] == room.key }
    other[:open] = true if other

    say "The lock turns. The way is open."
  end

  def oil(word)
    return say 'You have no oil.' unless @player.carrying?('oil can')

    item = room.find(word)
    return say "There is no #{word} here to oil." if item.nil?
    return say "Oiling the #{item} would achieve nothing." unless item.name == 'mechanism'

    if @player.flags.include?(:oiled)
      say 'It is oiled already.'
    else
      @player.flags << :oiled
      say 'You fill the reservoir. The mechanism turns freely.'
    end
  end

  def light(word)
    item = room.find(word)
    return say "There is no #{word} here." if item.nil?
    return say "You cannot light the #{item}." unless item.name == 'mechanism'
    return say 'You have nothing to light it with.' unless @player.carrying?('matches')
    return say 'It turns, but it will not catch. It is dry.' unless @player.flags.include?(:oiled)

    say <<~TEXT

      The wick takes. The light goes up through the glass and out into the
      fog, and the fog gives it back, and for a moment the whole white world
      is lit from inside.

      Somewhere below, on water you cannot see, a bell answers.
    TEXT
    @won = true
  end
end

# ------------------------------------------------------------------- the main

Game.new.run if __FILE__ == $PROGRAM_NAME

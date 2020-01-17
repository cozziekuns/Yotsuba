require_relative 'game'

#==================================================================================================
# ** Main
#==================================================================================================

# 67m33567p456678s
# 224m3p233478899s
# 234m234p234s78999s

# hand = Parser_Util.parse_hand('234m234p23478999s')
# TODO: Need to identify chiitoi and kokushi shanten 

# hand = Game_Hand.new
# hand.parse_from_string('2345s')

=begin
hand = Game_Hand.new
hand.parse_from_string('66m11112233p678s')
p hand.ukeire_outs

hand = Game_Hand.new
hand.parse_from_string('246788m24668p44s')
p hand.ukeire_outs

hand = Game_Hand.new
hand.parse_from_string('2568m128p13567s7z')
p hand.ukeire_outs

hand = Game_Hand.new
hand.parse_from_string('14m222333444p147s')
p hand.ukeire_outs
=end

require 'bigdecimal'
require 'bigdecimal/util'

WALL_SIZE = 136

unseen_tiles = 122
draws_left = 12
waits = 8

def calc_draw_percentage(unseen_tiles, draws, waits)
  result = BigDecimal("1")

  draws.times { |i|
    result *= unseen_tiles - waits - i
    result /= unseen_tiles - i
  }

  return 1 - result
end

=begin
def calc_win_percentage(unseen_tiles, draws, waits, shanten=1)
  p [unseen_tiles, draws, waits, shanten]
  return calc_draw_percentage(unseen_tiles, draws, waits) if shanten == 0
  
  win_percentage = BigDecimal("0")
  stay_chance = BigDecimal("1")

  draws.times { |i|
    advance_chance = calc_draw_percentage(unseen_tiles - i, 1, waits)

    win_percentage += stay_chance * advance_chance * calc_win_percentage(
      unseen_tiles - i - 1,
      draws - i - 1,
      3,
      shanten - 1,
    )

    stay_chance *= (1 - advance_chance)
  }

  return win_percentage
end
=end

# p calc_win_percentage(122 - 14, 3, 9, 1).round(8, BigDecimal::ROUND_UP).to_digits

hand = Game_Hand.new
hand.parse_from_string('246788m24668p44s')
p hand.ukeire_outs
# calc_win_percentage(hand, 18)

def create_tree(hand, unseen_tiles, draws, used_tiles)
  total_waits = hand.ukeire_outs.map { |tile| 4 - used_tiles[tile] }.sum

  if hand.shanten == 0
    win_percentage = calc_draw_percentage(unseen_tiles, draws, total_waits)
    return win_percentage
  end

  # We need to figure out the probability that we advance the hand
  stay_chance = BigDecimal("1")
  advance_chance = []

  draws.times { |i|
    raw_advance_chance = calc_draw_percentage(unseen_tiles - i, 1, total_waits)

    advance_chance[i] = stay_chance * raw_advance_chance
    stay_chance = stay_chance * (1 - raw_advance_chance) 
  }

  win_percentage = BigDecimal("0")

  hand.ukeire_outs.each { |out|
    tiles_plus_draw = hand.tiles + [out]
    tile_advance_chance = BigDecimal("1") * (4 - used_tiles[out]) / total_waits

    new_used_tiles = used_tiles.clone
    new_used_tiles[out] += 1

    highest_win_percentage_for_tile = 0.0

    tiles_plus_draw.uniq.each { |tile|
      win_percentage_for_tile = 0.0
     
      current_tiles = tiles_plus_draw.clone
      current_tiles.delete_at(current_tiles.index(tile))

      current_hand = Game_Hand.new
      current_hand.parse_from_tiles(current_tiles)
      next if current_hand.shanten >= hand.shanten

      (draws - 1).times { |i|
        win_percentage_for_tile += advance_chance[i] * tile_advance_chance * create_tree(
          current_hand,
          unseen_tiles - i - 1, 
          draws - i - 1,
          new_used_tiles,
        )
      }

      highest_win_percentage_for_tile = [highest_win_percentage_for_tile, win_percentage_for_tile].max
    }

    win_percentage += highest_win_percentage_for_tile
  }

  return win_percentage
end

def generate_wall_tiles(hand)
  wall_tiles = Array.new(34, 4)
  hand.tiles.each { |tile| wall_tiles[tile] -= 1 }

  return wall_tiles
end

def generate_used_tiles(hand)
  used_tiles = {}

  0.upto(33).each { |tile| used_tiles[tile] = 0 }
  hand.tiles.each { |tile| used_tiles[tile] += 1 }

  return used_tiles
end

t = Time.now
win_percentage = create_tree(hand, WALL_SIZE - hand.tiles.length - 15, 3, generate_used_tiles(hand))
p win_percentage.round(6, BigDecimal::ROUND_UP).to_digits
# p win_percentage
p Time.now - t
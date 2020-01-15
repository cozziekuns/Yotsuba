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

unseen_tiles = 122
draws_left = 12
waits = 8

def calc_draw_percentage(unseen_tiles, draws, waits)
  numerator = BigDecimal("1")
  draws.times { |i| numerator *= unseen_tiles - waits - i }

  denominator = BigDecimal("1")
  draws.times { |i| denominator *= unseen_tiles - i }

  return 1 - numerator / denominator
end

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

p calc_win_percentage(122 - 14, 3, 9, 1).round(8, BigDecimal::ROUND_UP).to_digits
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
#hand.parse_from_string('2345s')

hand = Game_Hand.new
hand.parse_from_string('66m11112233p678s')
p hand.ukeire_outs

hand = Game_Hand.new
hand.parse_from_string('246788m24668p44s')
p hand.ukeire_outs

hand = Game_Hand.new
hand.parse_from_string('2568m128p13567s7z')
p hand.ukeire_outs
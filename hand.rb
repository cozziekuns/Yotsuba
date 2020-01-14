#==================================================================================================
# ** Hand_Parser
#==================================================================================================

module Hand_Parser

  def self.parse_hand(hand_str)
    hand = parse_manzu(hand_str)
    hand += parse_pinzu(hand_str) 
    hand += parse_souzu(hand_str) 
    hand += parse_jihai(hand_str)
  
    return hand.sort
  end
  
  def self.parse_manzu(hand_str)
    match_data = /(\d+)m/.match(hand_str)
  
    return [] if not match_data
    return match_data[1].split('').map { |s| s.to_i - 1 }
  end
  
  def self.parse_pinzu(hand_str)
    match_data = /(\d+)p/.match(hand_str)
  
    return [] if not match_data
    return match_data[1].split('').map { |s| s.to_i + 9 - 1 }
  end
  
  def self.parse_souzu(hand_str)
    match_data = /(\d+)s/.match(hand_str)
  
    return [] if not match_data
    return match_data[1].split('').map { |s| s.to_i + 9 * 2 - 1 }
  end
    
  def self.parse_jihai(hand_str)
    match_data = /(\d+)z/.match(hand_str)
  
    return [] if not match_data
    return match_data[1].split('').map { |s| s.to_i + 9 * 3 - 1 }
  end

end

#==================================================================================================
# ** Hand_Scorer
#==================================================================================================

module Hand_Scorer

  def self.score_hand(hand, menzen, tsumo, wait_tile, wait_shape, round_wind=0, self_wind=0)
    return nil if not hand.is_winning_hand?

    p hand.winning_configurations.map { |configuration| 
      self.score_configuration(configuration, menzen, tsumo, wait_tile, wait_shape, round_wind, self_wind) 
    }
  end

  def self.score_configuration(configuration, menzen, tsumo, wait_tile, wait_shape, round_wind, self_wind)
    han = self.calculate_han(configuration, menzen, tsumo, wait_tile, wait_shape, round_wind, self_wind)
    fu = self.calculate_fu(configuration, menzen, tsumo, wait_tile, wait_shape, round_wind, self_wind)
      
    return [han, fu]
  end

  def self.calcuate_han(configuration, menzen, tsumo, wait_tile, wait_shape, round_wind, self_wind)
    han = 0

    han += 1 if menzen and tsumo
    han += 1 if is_pinfu?(configuration, menzen, wait_shape, round_wind, self_wind)
    han += 1 if is_tanyao?(configuration)
    han += get_yakuhai_han(configuration)

    if is_ryanpeikou?(configuration, menzen)
      han += 3
    elsif is_iipeikou?(configuration, menzen)
      han += 1
    end
  end

  def self.get_yakuhai_han(configuration)
    koutsu = configuration.select { |mentsu| Hand_Util.is_koutsu?(mentsu) }
    return koutsu.select { |koutsu| Hand_Util.is_value_tile?(koutsu[0]) }.length
  end

  def self.is_pinfu?(configuration, menzen, wait_shape, round_wind, self_wind)
    return false if not menzen
    return false if wait_shape != :ryanmen
    return false if configuration.any? { |mentsu| Hand_Util.is_koutsu?(mentsu) }

    atama = configuration.select { |mentsu| Hand_Util.is_toitsu?(mentsu) } 
    return false if Hand_Util.is_value_tile?(atama[0], round_wind, self_wind)
  end

  def self.is_tanyao?(configuration)
    return configuration.all? { |mentsu| 
      mentsu.none? { |tile| Hand_Util.is_kokushi_tile?(tile) }
    }
  end

  def self.is_iipeikou?(configuration, menzen)
    return false if not menzen

    shuntsu = configuration.select { |mentsu| Hand_Util.is_shuntsu?(mentsu) }
    return false if shuntsu.length < 2
    return shuntsu.uniq.length == shuntsu.length - 1
  end

  def self.is_ryanpeikou?(configuration, menzen)
    return false if not menzen

    shuntsu = configuration.select { |mentsu| Hand_Util.is_shuntsu?(mentsu) }
    return false if shuntsu.length != 4

    return shuntsu[2] == shuntsu[3] if shuntsu[0] == shuntsu[1]
    return shuntsu[1] == shuntsu[3] if shuntsu[0] == shuntsu[2]
    return shuntsu[1] == shuntsu[2] if shuntsu[0] == shuntsu[3]

    return false
  end

  def self.calculate_fu(configuration, menzen, tsumo, wait_tile, wait_shape, round_wind, self_wind)
    fu = 0

    configuration.each { |mentsu|
      # TODO: Add Handling for kans / calls
      if Hand_Util.is_koutsu?(mentsu)
        fu += Hand_Util.is_kokushi_tile?(mentsu[0]) ? 8 : 4
      end

      fu += 2 if mentsu.length == 2 and Hand_Util.is_value_tile?(mentsu[0], round_wind, self_wind)
    }

    # This fu calculation is already done for the mentsu fu
    fu -= (Hand_Util.is_kokushi_tile?(wait_tile) ? 4 : 2) if wait_shape == :shanpon and not tsumo
    fu += 2 if not [:ryanmen, :shanpon].include?(wait_shape)

    fu += 2 if tsumo
    fu += 10 if menzen and not tsumo

    return fu
  end

end

#==================================================================================================
# ** Hand_Util
#==================================================================================================

module Hand_Util

  def self.tile_value(tile)
    return tile % 9 + 1
  end

  def self.is_terminal_tile?(tile)
    return [1, 9].include?(tile_value(tile)) 
  end

  def self.is_honor_tile?(tile)
    return tile.between?(27, 33)
  end

  def self.is_kokushi_tile?(tile)
    return (is_terminal_tile?(tile) or is_honor_tile?(tile))
  end

  def self.is_value_tile?(tile, round_wind, self_wind)
    return true if is_dragon_tile?(tile)
    return true if tile == 27 - round_wind
    return true if tile == 27 - self_wind
    return false
  end

  def self.is_wind_tile?(tile)
    return tile.between?(27, 30)
  end
  
  def self.is_dragon_tile?(tile)
    return tile.between?(31, 33)
  end

  def self.is_koutsu?(mentsu)
    return (mentsu.length == 3 and mentsu.uniq.length == 1)
  end

  def self.is_toitsu?(mentsu)
    return (mentsu.length == 2 and mentsu[0] == mentsu[1])
  end

  def self.is_shuntsu?(mentsu)
    return false if mentsu.length != 3

    sorted_mentsu = mentsu.sort
    return (
      tile_value(sorted_mentsu[0]) + 1 == tile_value(sorted_mentsu[1]) and
      tile_value(sorted_mentsu[0]) + 2 == tile_value(sorted_mentsu[2])
    )
  end

end
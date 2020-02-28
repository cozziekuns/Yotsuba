require_relative 'hand'

#==================================================================================================
# ** Game_Hand
#==================================================================================================

class Game_Hand

  #------------------------------------------------------------------------------------------------
  # * Public Instance Variables
  #------------------------------------------------------------------------------------------------

  attr_reader   :shanten
  attr_reader   :tiles
  attr_reader   :lowest_shanten_configurations

  #------------------------------------------------------------------------------------------------
  # * Initialization Methods
  #------------------------------------------------------------------------------------------------

  def initialize
    @tiles = []
    @shanten = 0
    @mentsu_configurations = []
    @lowest_shanten_configurations = []
  end

  def parse_from_string(string)
    @tiles = Hand_Parser.parse_hand(string).sort
    refresh
  end

  def parse_from_tiles(tiles)
    $counts += 1
    @tiles = tiles.sort
    refresh
  end

  def refresh
    @mentsu_configurations = calc_mentsu_tree(@tiles) 
    process_lowest_shanten_configurations
  end

  #------------------------------------------------------------------------------------------------
  # * Properties
  #------------------------------------------------------------------------------------------------

  def is_winning_hand?
    return false if not @tiles.length == 14
    return winning_configurations.size > 0
  end

  def is_winning_configuration?(configuration)
    return false if configuration.select { |mentsu| mentsu.length == 3 }.length != 4

    atama = configuration.select { |mentsu| mentsu.length == 2 }
    return false if atama.length != 1
    return atama[0][0] == atama[0][1]
  end

  def winning_configurations
    return @lowest_shanten_configurations.select { |configuration| 
      is_winning_configuration?(configuration) 
    }
  end

  def get_ukeire_outs_for_configuration(configuration)
    outs = []

    head_candidates = configuration.select { |group| 
      group.length == 2 and group.uniq.length == 1
    }

    headless = head_candidates.empty?

    mentsu = configuration.select { |group| group.length == 3 }

    incomplete_shapes = configuration.select { |group| group.length == 2 }
    incomplete_shapes.each { |shape|
      # If all our shapes are locked in, and we only have one toitsu,
      # the head must be the toitsu and cannot be an ankou.
      if mentsu.length + incomplete_shapes.length > 4
        next if head_candidates.length == 1 and shape.uniq.length == 1
      end

      outs += get_outs_for_shape(shape) 
    }

    floating_tiles = configuration.select { |group| group.length == 1 }
    floating_tiles.each { |float|
      # If there are not enough taatsu, any connecting will improve the shanten
      if mentsu.length + incomplete_shapes.length - (headless ? 0 : 1) < 4
        outs.push(float[0])

        if not Hand_Util.is_honor_tile?(float[0])
          outs.push(float[0] - 2) if Hand_Util.tile_value(float[0]) > 2
          outs.push(float[0] - 1) if Hand_Util.tile_value(float[0]) > 1
          outs.push(float[0] + 1) if Hand_Util.tile_value(float[0]) < 9
          outs.push(float[0] + 2) if Hand_Util.tile_value(float[0]) < 8
        end
      end
    }

    if headless
      # The rest of the floating tiles can be used as heads
      outs += configuration.select { |group| group.length == 1 }.map { |group| group[0] }
    end

    return outs.uniq.sort
  end

  def ukeire_outs
    return @lowest_shanten_configurations.map { |configuration|
      get_ukeire_outs_for_configuration(configuration)
    }.flatten.uniq.sort
  end

  #-----------------------------------------------------------------------------------------------
  # * Ukeire Helper Methods
  #-----------------------------------------------------------------------------------------------

  def get_shanten_for_configuration(configuration)
    shanten = 9

    # Filter out the atama for shanten calculations
    atama = configuration.select { |group| group.uniq.length == 1 }.max { |group| group.size }
    shanten -= atama.length

    configuration = configuration.clone
    configuration.delete_at(configuration.index(atama))

    mentsu = configuration.sort { |b, a| b.length - a.length }[0...4]
    return shanten - mentsu.sum { |group| group.length - 1 }
  end
  
  def get_outs_for_shape(shape)
    # Toitsu
    if shape.uniq.length == 1
      return [shape[0]]
    # Kanchan
    elsif shape[0] == shape[1] - 2
      return [shape[0] + 1]
    # Penchan / Ryanmen
    elsif shape[0] == shape[1] - 1
      outs = []
      outs.push(shape[0] - 1) if Hand_Util.tile_value(shape[0]) > 1
      outs.push(shape[1] + 1) if Hand_Util.tile_value(shape[1]) < 9
      
      return outs
    end
  end

  #-----------------------------------------------------------------------------------------------
  # * Mentsu Tree Calculation
  #-----------------------------------------------------------------------------------------------
    
  def calc_mentsu_tree(hand)
    candidate_configurations = []
    max_depth = -1
    
    queue = [[hand, []]]

    iterations = 0

    until queue.empty?
      iterations += 1
      hand, old_hand = queue.shift

      break if max_depth > -1 and old_hand.length > max_depth
      
      if hand.empty?
        if old_hand.any? { |group| group.uniq.length == 1 }
          max_depth = old_hand.length
          candidate_configurations.push(old_hand)
        end

        next
      end

      if hand.length > 2
        # Koutsu
        if hand[0] == hand[1] and hand[0] == hand[2]
          queue.push([hand[3..-1], old_hand + [hand[0..2]]])
        end

        # Shuntsu
        if Hand_Util.tile_value(hand[0]) < 8 and hand.include?(hand[0] + 1) and hand.include?(hand[0] + 2)
          new_hand = hand[1..-1]
          new_hand.delete_at(new_hand.index(hand[0] + 1))
          new_hand.delete_at(new_hand.index(hand[0] + 2))

          queue.push([new_hand, old_hand + [[hand[0], hand[0] + 1, hand[0] + 2]]])
        end
      end

      if hand.length > 2
        # Toitsu
        if hand[0] == hand[1]
          queue.push([hand[2..-1], old_hand + [hand[0...2]]])
        end

        # Ryanmen / Penchan
        if Hand_Util.tile_value(hand[0]) < 9 and hand.include?(hand[0] + 1)
          new_hand = hand[1..-1]
          new_hand.delete_at(new_hand.index(hand[0] + 1))

          queue.push([new_hand, old_hand + [[hand[0], hand[0] + 1]]])
        end

        # Kanchan
        if Hand_Util.tile_value(hand[0]) < 8 and hand.include?(hand[0] + 2)
          new_hand = hand[1..-1]
          new_hand.delete_at(new_hand.index(hand[0] + 2))

          queue.push([new_hand, old_hand + [[hand[0], hand[0] + 2]]])
        end
      end
      
      # Tanki
      queue.push([hand[1..-1], old_hand + [[hand[0]]]])
    end

    return candidate_configurations
  end

  #------------------------------------------------------------------------------------------------
  # * Mentsu Configuration Processing
  #------------------------------------------------------------------------------------------------

  def process_lowest_shanten_configurations
    configuration_shanten = @mentsu_configurations.map { |configuration|
      get_shanten_for_configuration(configuration)
    }

    @shanten = configuration_shanten.min
    
    configuration_shanten.each_with_index { |shanten, i| 
      @lowest_shanten_configurations.push(@mentsu_configurations[i]) if shanten == @shanten
    }
  end

end
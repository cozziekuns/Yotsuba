require_relative 'hand'

#==================================================================================================
# ** Game_Hand
#==================================================================================================

class Game_Hand

  #------------------------------------------------------------------------------------------------
  # * Public Instance Variables
  #------------------------------------------------------------------------------------------------

  attr_reader   :shanten

  #------------------------------------------------------------------------------------------------
  # * Initialization Methods
  #------------------------------------------------------------------------------------------------

  def initialize
    @tiles = []
    @shanten = 0
    @mentsu_tree = {}
    @mentsu_configurations = {}
    @lowest_shanten_configurations = []
  end

  def parse_from_string(string)
    @tiles = Hand_Parser.parse_hand(string)
    refresh
  end

  def parse_from_tiles(tiles)
    @tiles = tiles
    refresh
  end

  def refresh
    @mentsu_tree = calc_mentsu_tree(@tiles) 
    process_mentsu_configurations(@mentsu_tree)
    process_lowest_shanten_configurations
    empty_mentsu_configuration_memo
    p @shanten
  end

  def empty_mentsu_configuration_memo
    # Empty the mentsu configuration memo to save memory
    @mentsu_configuration_memo = {}
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

  def ukeire_outs
    outs = []

    # Uke-ire outs are defined as any draw that would decrease the shanten of the hand
    @lowest_shanten_configurations.each { |configuration|
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
        if mentsu.length + incomplete_shapes.length < 4
          outs.push(float[0])

          if not Hand_Util.is_honor_tile?(float[0])
            outs.push(float[0] - 2) if Hand_Util.tile_value(float[0]) > 2
            outs.push(float[0] - 1) if Hand_Util.tile_value(float[0]) > 1
            outs.push(float[0] + 1) if Hand_Util.tile_value(float[0]) < 9
            outs.push(float[0] + 2) if Hand_Util.tile_value(float[0]) < 8
          end
        end
      }

      next if not headless

      # If we are headless and taatsu over, we can use the tiles in our
      # incomplete shapes for our head
      if mentsu.length + incomplete_shapes.length > 4
        incomplete_shapes.each { |shape| 
          outs += [shape[0], shape[1]] if shape.uniq.length == 2
        }
      end

      # The rest of the floating tiles can be used as heads
      outs += configuration.select { |group| group.length == 1 }.map { |group| group[0] }
    }

    return outs.select { |out| @tiles.count(out) < 4 }.uniq.sort
  end

  #-----------------------------------------------------------------------------------------------
  # * Ukeire Helper Methods
  #-----------------------------------------------------------------------------------------------

  def get_shanten_for_configuration(configuration)
    tiles = configuration.flatten
    # Configuration must be one of 1, 4, 7, 10, 13
    shanten = (tiles.length - 1) / 3 * 2
    mentsu = (tiles.length - 1) / 3

    # Filter out the atama for shanten calculations
    atama = configuration.find { |group| group.length == 2 and group.uniq.length == 1 }

    if atama 
      shanten -= 1
      configuration = configuration.clone
      configuration.delete_at(configuration.index(atama))
    end

    configuration.sort { |group| group.length }.each { |group|
      break if mentsu == 0
      if group.length > 1
        shanten -= group.length - 1
        mentsu -= 1
      end
    }

    return shanten
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
      outs.push(shape[1] + 1) if Hand_Util.tile_value(shape[0]) < 9
      
      return outs
    end
  end

  #-----------------------------------------------------------------------------------------------
  # * Mentsu Tree Calculation
  #-----------------------------------------------------------------------------------------------

  def calc_mentsu_tree(hand)
    @mentsu_configuration_memo ||= {}
    return @mentsu_configuration_memo[hand] if @mentsu_configuration_memo[hand]

    configurations = {}
    return configurations if hand.empty?

    update_koutsu_configurations(hand, configurations)
    update_toitsu_configurations(hand, configurations)
    update_shuntsu_configurations(hand, configurations)
    update_ryanmen_configurations(hand, configurations)
    update_kanchan_configurations(hand, configurations)
    update_tanki_configurations(hand, configurations)

    @mentsu_configuration_memo[hand] = configurations
    return configurations
  end

  def update_koutsu_configurations(hand, configurations)
    return if hand[0] != hand[1] or hand[0] != hand[2]

    new_hand = hand[3..-1]
    configurations[[hand[0]] * 3] = calc_mentsu_tree(new_hand)
  end

  def update_toitsu_configurations(hand, configurations)
    return if hand[0] != hand[1]

    new_hand = hand[2..-1]
    configurations[[hand[0]] * 2] = calc_mentsu_tree(new_hand)
  end

  def update_shuntsu_configurations(hand, configurations)
    return if Hand_Util.tile_value(hand[0]) >= 8
    return if not hand.include?(hand[0] + 1) or not hand.include?(hand[0] + 2)

    new_hand = hand[1..-1]
    new_hand.delete_at(new_hand.index(hand[0] + 2))
    new_hand.delete_at(new_hand.index(hand[0] + 1))
  
    configurations[[hand[0], hand[0] + 1, hand[0] + 2]] = calc_mentsu_tree(new_hand)
  end

  def update_ryanmen_configurations(hand, configurations)
    return if Hand_Util.tile_value(hand[0]) == 9
    return if not hand.include?(hand[0] + 1)

    new_hand = hand[1..-1]
    new_hand.delete_at(new_hand.index(hand[0] + 1))
  
    configurations[[hand[0], hand[0] + 1]] = calc_mentsu_tree(new_hand)
  end

  def update_kanchan_configurations(hand, configurations)
    return if Hand_Util.tile_value(hand[0]) >= 8
    return if not hand.include?(hand[0] + 2)

    new_hand = hand[1..-1]
    new_hand.delete_at(new_hand.index(hand[0] + 2))
      
    configurations[[hand[0], hand[0] + 2]] = calc_mentsu_tree(new_hand)
  end

  def update_tanki_configurations(hand, configurations)
    new_hand = hand[1..-1]
    configurations[[hand[0]]] = calc_mentsu_tree(new_hand)
  end

  #------------------------------------------------------------------------------------------------
  # * Mentsu Configuration Processing
  #------------------------------------------------------------------------------------------------

  def process_mentsu_configurations(hand, old_hand=[])
    if hand.empty?
      @mentsu_configurations[old_hand.length] ||= []
      @mentsu_configurations[old_hand.length].push(old_hand)
    end
  
    hand.keys.each { |mentsu|
      process_mentsu_configurations(hand[mentsu], old_hand + [mentsu])
    }
  end

  def process_lowest_shanten_configurations
    candidate_configurations = @mentsu_configurations[@mentsu_configurations.keys.min]
    configuration_shanten = candidate_configurations.map { |configuration|
      get_shanten_for_configuration(configuration)
    }

    @shanten = configuration_shanten.min
    
    configuration_shanten.each_with_index { |shanten, i| 
      @lowest_shanten_configurations.push(candidate_configurations[i]) if shanten == @shanten
    }
  end

end
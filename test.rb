hand = [2, 3, 4, 5]

def calc_mentsu_tree(hand)
  candidate_configurations = []

  max_depth = -1
  queue = [[hand, [], 0]]

  until queue.empty?
    hand, old_hand, depth = queue.shift

    break if max_depth > -1 and depth >= max_depth

    if hand.include?(hand[0] + 1) and hand.include?(hand[0] + 2)
      if hand.length == 3
        max_depth = depth + 1
        candidate_configurations.push(old_hand + [[hand[0], hand[1], hand[2]]])
      else
        queue.push([hand[3..-1], old_hand + [[hand[0], hand[1], hand[2]]], depth + 1])
      end
    end

    if hand.length == 1
      max_depth = depth + 1
      candidate_configurations.push(old_hand + [[hand[0]]])
    else
      queue.push([hand[1..-1], old_hand + [[hand[0]]], depth + 1])
    end
  end

  return candidate_configurations

end

p calc_mentsu_tree(hand)

__END__
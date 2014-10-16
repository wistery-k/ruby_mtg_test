# -*- coding: utf-8 -*-
class Array
  def delete_first(e)
    delete_at(index(e))
  end
end

def ia(s)
  if "aeiou".index(s[0].downcase) != nil
    "an " + s
  else
    "a " + s
  end
end

$fresh_id = 0

def fresh_id
  ret = $fresh_id
  $fresh_id += 1
  return ret
end

Colors = [:r, :g, :b, :w, :u]
Manas = [:r, :g, :b, :w, :u, :l]

class Win < Exception
  def initialize(who)
    @who = who
  end
  attr_reader :who
end

class State
  def initialize
    @ap = 0
    @turn = 0
    @step = :main1
    @first_turn = true
    @stack = []
    @deck = [[],[]]
    @hand = [[],[]]
    @grave = [[],[]]
    @play = {}
    @land_played = 0
    @mana = [{},{}]
    @life = [20,20]
  end
  attr_accessor :ap, :turn, :step, :first_turn, :stack, :deck, :hand, :grave, :play, :land_played, :mana, :life

  def dp
    1 - @ap
  end

  def reset_mana
    mana[0] = {:r => 0,:g => 0,:b => 0,:w => 0,:u => 0, :l => 0}
    mana[1] = {:r => 0,:g => 0,:b => 0,:w => 0,:u => 0, :l => 0}
  end
end

def pc(str)
  ans = {:gen => 0, :u => 0, :b => 0, :r => 0, :g => 0, :w => 0}
  str.each_char do |c|
    ix = "RGBWU".index(c)
    if ix != nil
      ans[Manas[ix]] += 1
    else
      ans[:gen] += c.to_i
    end
  end
  return ans
end

def basicLand(m)
  { :type => :land,
    :activated_ability => [{:mana_ability => true, :cost => [:tap], :resolve => proc{|s,this| s.mana[this[:controller]][m] += 1}}] }
end

def vanilla(cost, power, tough)
  { :type => :creature,
    :cost => pc(cost),
    :power => power,
    :tough => tough }
end
    
Island = basicLand(:u)
Mountain = basicLand(:r)
Forest = basicLand(:g)
Swamp = basicLand(:b)
Plains = basicLand(:w)

Wetland_Sambar    = vanilla("1U", 2, 1)
Rotting_Mastodon  = vanilla("4B", 2, 8)
Summit_Prowler    = vanilla("2RR", 4, 3)
Alpine_Grizzly    = vanilla("2G", 4, 2)
Tusked_Colossodon = vanilla("4GG", 6, 5)

End_Hostilities = { 
  :type => :sorcery,
  :cost => "3WW",
  :resolve => proc{|s,this| s.play.each{|id,p| s.destroy(id) if p[:type] == :creature }}
}

Erase = {
  :type => :instant,
  :cost => "W",
  :resolve => proc{|s,this| s.exile(this[:target])}
}

Kill_Shot = {
  :type => :instant,
  :cost => "2W",
  :resolve => proc{|s,this| s.destroy(this[:target]) if s.play[this[:target]][:attacking] }
}

Smite_the_Monstrous = {
  :type => :instant,
  :cost => "3W",
  :resolve => proc{|s,this| s.destroy(this[:target]) if s.play[this[:target]][:power] >= 4 }
}

Waterwhirl = {
  :type => :instant,
  :cost => "5U",
  :resolve => proc{|s,this| s.bounce(this[:target][0]); s.bounce(this[:target][1])}
}

def db(card)
  Object.const_get(card).dup
end

def each_player(&b)
  2.times{|i| b.call(i)}
end

def do_stack(s, ai, sorcery)
  return if not sorcery

  p = s.ap
  pass = 0

  while true
    # state based action
    raise Win.new(s.dp) if s.life[s.ap] <= 0
    raise Win.new(s.ap) if s.life[s.dp] <= 0

    each_player do |pl|
      s.play.select do |id, permanent|
        if permanent[:type] == :creature and permanent[:damage] >= permanent[:tough] then
          s.grave[pl] << permanent[:card]
          false
        end
        true
      end
    end
    
    res = ai[p].stack(s) # TODO: stack
    
    case res[:type]
    when :pass
      pass += 1
      if pass >= 2
        if s.stack == []
          break
        else
          spell = s.stack.pop()
          puts "#{spell[:card]} resolves."
          if spell[:type] == :creature
            permanent = db(spell[:card])
            permanent[:controller] = spell[:controller]
            permanent[:tapped] = false
            permanent[:damage] = 0
            permanent[:card] = spell[:card]
            permanent[:sick] = true
            s.play[fresh_id()] = permanent
          else
            raise 0
          end
          p = s.ap
          pass = 0
        end
      else
        p = (p + 1) % 2
      end
    when :setland
      puts "Player #{s.ap} played #{ia(res[:card])}."
      card = res[:card]
      permanent = db(card)
      permanent[:card] = card
      permanent[:controller] = p
      permanent[:tapped] = false
      s.play[fresh_id()] = permanent
      s.land_played += 1
      s.hand[s.ap].delete_first(res[:card])
    when :activate
      id = res[:id]
      permanent = s.play[id]
      a = permanent[:activated_ability][res[:which]]
      puts "Player #{p} activated an ability of #{permanent[:card]}"
      if a[:mana_ability]
        a[:cost].each do |cost|
          case cost
          when :tap
            permanent[:tapped] = true
          else
            raise 0
          end
        end
        a[:resolve].call(s, s.play[id])
      else
        stack << a
      end
    when :cast
      card = res[:card]
      puts "Player #{p} cast #{card}"
      res[:cost].each do |k, v|
        case k
        when :u, :b, :r, :g, :w, :l
          s.mana[p][k] -= v
        else
          raise 0
        end
      end
      d = db(card)
      s.stack << { :type => d[:type], :card => card, :controller => p, :x => res[:x] }
    end
  end
end

def main(d, a)
  each_player do |pl|
    a[pl].init(pl)
  end
  s = State.new
  kept = [false, false]
  7.downto(1) do |i|
    each_player do |pl|
      next if kept[pl]
      dd = d[pl].dup.shuffle
      h = []
      i.times do
        h << dd.pop
      end
      if not a[pl].mulligan?(h) then
        kept[pl] = true
        s.deck[pl] = dd
        s.hand[pl] = h
        puts "player #{pl} kept #{i} cards."
      end
    end
  end

  s.ap = 0
  s.turn = 0
  s.first_turn = true

  begin
  while true
    puts ""
    puts "Turn #{s.turn}."
    puts "#Library #{s.deck[s.ap].length}"
    puts "#Hand #{s.hand[s.ap]}"
    puts "[#{s.life[0]}, #{s.life[1]}]"

    s.land_played = 0
    s.reset_mana()
    
    if not s.first_turn then
      # untap
      s.step = :untap
      s.play.each do |id, permanent|
        permanent[:sick] = false
        if permanent[:controller] == s.ap
          permanent[:tapped] = false
        end
      end

      # upkeep
      s.step = :upkeep
      do_stack(s, a, false)

      # draw
      s.step = :draw
      if s.deck[s.ap].empty?
        puts "Player #{s.ap}'s library is out of cards."
        break
      end
      dc = s.deck[s.ap].pop
      s.hand[s.ap] << dc
      puts "Player #{s.ap} drew #{ia(dc)}."
    end

    # main1
    s.step = :main1
    do_stack(s, a, true)

    # begin combat
    s.step = :begin_combat
    do_stack(s, a, false)

    # attack
    s.step = :declare_attackers
    attackers = a[s.ap].declare_attackers(s) # set of ids of attacking creatures.
    puts "Attacks with %s" % attackers.map{|id|s.play[id][:card]}.to_s

    attackers.each do |id|
      s.play[id][:tapped] = true
      s.play[id][:attacking] = true
    end

    atob = {}

    do_stack(s, a, false)

    # block
    s.step = :declare_blockers
    blockers = a[s.ap].declare_blockers(s) # map from ids of blocking creatures to [id] of blocked creatures by them.
    blockers.each do |k, v|
      s.play[k][:blocking] = true
      v.each do |w|
        s.play[w][:blocked] = true
        atob[w] = [] if atob.has_key?(w)
        atob[w] << k
      end
    end

    atob.each do |k, v|
      if v.length >= 2
        s.damage_assign_order[k] = a[s.ap].damage_assign_order(k)
      end
    end

    blockers.each do |k, v|
      if v.length >= 2
        s.damage_assign_order[k] = a[s.dp].damage_assign_order(k)
      end
    end

    do_stack(s, a, false)

    life_pre = s.life.dup

    # damage
    # each attacking creatures and blocking creatures assign damages that are equal to their power.
    s.step = :damage
    attackers.each do |id|
      permanent = s.play[id]
      power = permanent[:power]
      if not permanent[:blocked]
        s.life[s.dp] -= power
      else
        s.damage_assign_order[id].each do |b|
          blocker = s.play[b]
          d = min(power, blocker[:tough])
          blocker[:damage] += d
          power -= d
        end
        if false and 
          s.life[s.dp] -= power
        end
      end
    end

    blockers.each do |k, v|
      pt = s.play[k]
      power = pt[:power]
      if pt[:blocking]
        s.block_assign_order.each do |w|
          d = [power, s.play[w][:tough]].max
          s.play[w][:damage] += power
          power -= d
        end
      end
    end

    if life_pre != s.life
      puts "#{life_pre} => #{s.life}"
    end

    do_stack(s, a, false)

    # end combat
    s.step = :end_combat
    do_stack(s, a, false)

    # main 2
    s.step = :main2
    do_stack(s, a, true)

    # end
    s.step = :end
    do_stack(s, a, false)

    # cleanup
    s.step = :cleanup

    s.first_turn = false
    s.ap = s.dp
    s.turn += 1

    if s.turn > 20
      puts "The game is too long lasting. Draw."
      break
    end

    gets
  end
  rescue Win => e
    puts "Player #{e.who} wins!"
  end
end

def make_deck(mp)
  d = []
  mp.each do |k, v|
    v.times do
      d << k
    end
  end
  return d
end

deck1 = make_deck({
  "Wetland_Sambar" => 20,
  "Island" => 10
})

deck2 = make_deck({
  "Rotting_Mastodon" => 15,
  "Swamp" => 15
})

def calc_pay(manacost, manapool)
  pay = manacost.dup
  pay[:l] = 0
  Colors.each do |c|
    return nil if manapool[c] < manacost[c]
    manapool[c] -= manacost[c]
  end
  Manas.each do |c|
    use = [pay[:gen], manapool[c]].min
    pay[:gen] -= use
    pay[c] += use
  end
  return nil if pay[:gen] > 0
  pay.delete(:gen)
  return pay
end

class BakaAi
  def init(who)
    @who = who
  end

  def mulligan?(h)
    false
  end

  def stack(s)
    return {:type => :pass } if s.ap != @who

    ix = s.hand[@who].index do |card|
      permanent = db(card)
      permanent[:type] == :land
    end

    if s.land_played == 0 && s.stack.empty? && ix != nil then
      return {:type => :setland, :card => s.hand[@who][ix] }
    elsif s.stack.empty?
      s.play.each do |id, permanent|
        if permanent[:controller] == @who and permanent[:type] == :land and not permanent[:tapped]
          return { :type => :activate, :id => id, :which => 0 }
        end
      end
      s.hand[@who].each do |card|
        data = db(card)
        if data[:type] != :land
          pay = calc_pay(data[:cost].dup, s.mana[@who].dup)
          if pay != nil
            return { :type => :cast, :cost => pay, :card => card }
          end
        end
      end
      {:type => :pass}
    else
      {:type => :pass}
    end
  end

  def declare_attackers(s)
    # attack with all creatures
    s.play.map do |id, permanent|
      if permanent[:controller] == @who and permanent[:type] == :creature and not permanent[:sick]
        id
      else
        nil
      end
    end.compact
  end

  def declare_blockers(s)
    # no block
    {}
  end
end

ai1 = BakaAi.new
ai2 = BakaAi.new

main([deck1, deck2], [ai1, ai2])

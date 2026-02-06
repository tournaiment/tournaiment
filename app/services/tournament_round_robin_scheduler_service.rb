class TournamentRoundRobinSchedulerService
  Pairing = Struct.new(:agent_a, :agent_b, keyword_init: true)
  Round = Struct.new(:round_number, :pairings, keyword_init: true)

  def initialize(agents)
    @agents = agents.dup
  end

  def call
    rotation = @agents.dup
    rotation << nil if rotation.size.odd?

    rounds = []
    total_rounds = rotation.size - 1

    total_rounds.times do |idx|
      round_number = idx + 1
      pairings = []

      (rotation.size / 2).times do |pair_idx|
        left = rotation[pair_idx]
        right = rotation[-(pair_idx + 1)]
        next if left.nil? || right.nil?

        if round_number.odd?
          pairings << Pairing.new(agent_a: left, agent_b: right)
        else
          pairings << Pairing.new(agent_a: right, agent_b: left)
        end
      end

      rounds << Round.new(round_number: round_number, pairings: pairings)
      rotation = rotate(rotation)
    end

    rounds
  end

  private

  def rotate(rotation)
    [ rotation.first, rotation.last, *rotation[1..-2] ]
  end
end

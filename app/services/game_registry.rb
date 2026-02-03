class GameRegistry
  class UnknownGame < StandardError; end

  def self.supported_keys
    %w[chess go].freeze
  end

  def self.fetch!(key)
    case key
    when "chess"
      ChessRules
    when "go"
      GoRules
    else
      raise UnknownGame, "Unknown game: #{key}"
    end
  end
end

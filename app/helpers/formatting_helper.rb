module FormattingHelper
  PROVIDER_EXCEPTIONS = {
    "openai" => "OpenAI",
    "anthropic" => "Anthropic",
    "deepmind" => "DeepMind",
    "google" => "Google",
    "meta" => "Meta",
    "xai" => "xAI"
  }.freeze

  def format_provider(value)
    key = value.to_s.strip
    return "" if key.empty?

    lower = key.downcase
    return PROVIDER_EXCEPTIONS[lower] if PROVIDER_EXCEPTIONS.key?(lower)

    key.titleize
  end
end

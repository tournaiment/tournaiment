require "redcarpet"

class DocsRenderer
  def initialize
    @renderer = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(with_toc_data: true),
      fenced_code_blocks: true,
      tables: true,
      autolink: true
    )
  end

  def render(path)
    @renderer.render(File.read(path))
  end
end

class DocsController < ApplicationController
  def show
    doc = params[:id].to_s
    return head :not_found unless doc == "getting-started"

    path = Rails.root.join("docs", "getting-started.md")
    @content_html = DocsRenderer.new.render(path)
  end
end

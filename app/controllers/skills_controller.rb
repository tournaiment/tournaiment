class SkillsController < ApplicationController
  SKILL_ROOT = Rails.root.join("docs", "skills", "tournaiment").freeze
  MARKDOWN_TYPE = "text/markdown; charset=utf-8".freeze
  JSON_TYPE = "application/json; charset=utf-8".freeze
  SKILL_FILE_CANDIDATES = {
    "skill.md" => %w[SKILL.md skill.md],
    "heartbeat.md" => %w[HEARTBEAT.md heartbeat.md],
    "notifications.md" => %w[NOTIFICATIONS.md notifications.md]
  }.freeze

  def manifest
    path = SKILL_ROOT.join("manifest.json")
    return head :not_found unless path.file?

    send_data path.binread, type: JSON_TYPE, disposition: "inline"
  end

  def show
    version = params[:version].to_s
    filename = params[:file].to_s
    normalized = filename.downcase
    return head :not_found if version.blank? || normalized.blank?

    version_root = skill_version_root(version)
    return head :not_found if version_root.blank?

    path = resolve_skill_file(version_root: version_root, normalized_file: normalized)
    return head :not_found if path.blank? || !path.file?

    send_data path.binread, type: MARKDOWN_TYPE, disposition: "inline"
  end

  private

  def available_versions
    @available_versions ||= begin
      Dir.children(SKILL_ROOT).select { |entry| SKILL_ROOT.join(entry).directory? }
    end
  end

  def skill_version_root(version)
    return nil unless available_versions.include?(version)

    SKILL_ROOT.join(version)
  end

  def resolve_skill_file(version_root:, normalized_file:)
    candidates = SKILL_FILE_CANDIDATES[normalized_file]
    return nil if candidates.blank?

    candidates.map { |candidate| version_root.join(candidate) }.find(&:file?)
  end
end

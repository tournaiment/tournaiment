module Admin
  class TournamentsController < BaseController
    before_action :set_tournament, only: [ :show, :edit, :update, :start, :cancel, :invalidate, :time_controls, :repair_health ]

    def index
      @tournaments = Tournament.order(created_at: :desc)
    end

    def new
      @tournament = Tournament.new(
        status: "registration_open",
        format: "single_elimination",
        game_key: "chess",
        time_control: "rapid",
        rated: true
      )
      prepare_form_time_controls
    end

    def create
      @tournament = Tournament.new(tournament_params)
      prepare_form_time_controls

      unless validate_time_control_selection(@tournament, @selected_preset_ids, @locked_preset_id)
        return render :new, status: :unprocessable_entity
      end

      Tournament.transaction do
        @tournament.save!
        sync_tournament_time_controls!(@tournament, @selected_preset_ids, @locked_preset_id)
      end

      AuditLog.log!(actor: current_admin, action: "admin.tournament_created", auditable: @tournament)
      redirect_to admin_tournament_path(@tournament), notice: "Tournament created."
    rescue ActiveRecord::RecordInvalid
      prepare_form_time_controls
      render :new, status: :unprocessable_entity
    end

    def show
      @standings = TournamentStandingsService.new(@tournament).call
      @available_presets = available_presets
      @notification_stats = notification_stats
      @notification_events = notification_events
      @health_report = TournamentHealthCheckService.new(tournament: @tournament).report
    end

    def edit
      prepare_form_time_controls
    end

    def update
      @tournament.assign_attributes(tournament_params)
      prepare_form_time_controls

      unless validate_time_control_selection(@tournament, @selected_preset_ids, @locked_preset_id)
        return render :edit, status: :unprocessable_entity
      end

      Tournament.transaction do
        @tournament.save!
        sync_tournament_time_controls!(@tournament, @selected_preset_ids, @locked_preset_id)
      end

      AuditLog.log!(actor: current_admin, action: "admin.tournament_updated", auditable: @tournament)
      redirect_to admin_tournament_path(@tournament), notice: "Tournament updated."
    rescue ActiveRecord::RecordInvalid
      prepare_form_time_controls
      render :edit, status: :unprocessable_entity
    end

    def start
      TournamentOrchestrator.new(@tournament).start!
      AuditLog.log!(actor: current_admin, action: "admin.tournament_started", auditable: @tournament)
      redirect_to admin_tournament_path(@tournament), notice: "Tournament started."
    rescue TournamentOrchestrator::Error => e
      redirect_to admin_tournament_path(@tournament), alert: e.message
    end

    def cancel
      AdminTournamentLifecycleService.new(tournament: @tournament, admin: current_admin).cancel!
      redirect_to admin_tournament_path(@tournament), notice: "Tournament cancelled and ratings rolled back."
    end

    def invalidate
      AdminTournamentLifecycleService.new(tournament: @tournament, admin: current_admin).invalidate!
      redirect_to admin_tournament_path(@tournament), notice: "Tournament invalidated and ratings rolled back."
    end

    def time_controls
      allowed_ids, locked_id = selected_time_control_params
      valid_ids = valid_time_control_ids(@tournament, allowed_ids)
      if valid_ids.sort != allowed_ids.sort
        return redirect_to admin_tournament_path(@tournament), alert: "One or more selected presets are invalid for this tournament."
      end
      if locked_id.present? && !valid_ids.include?(locked_id)
        return redirect_to admin_tournament_path(@tournament), alert: "Locked preset is invalid for this tournament."
      end

      Tournament.transaction do
        sync_tournament_time_controls!(@tournament, valid_ids, locked_id)
      end

      AuditLog.log!(
        actor: current_admin,
        action: "admin.tournament_time_controls_updated",
        auditable: @tournament,
        metadata: { locked_time_control_preset_id: locked_id, allowed_time_control_preset_ids: valid_ids }
      )
      redirect_to admin_tournament_path(@tournament), notice: "Tournament time controls updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_tournament_path(@tournament), alert: e.message
    end

    def repair_health
      report = TournamentHealthCheckService.new(tournament: @tournament, actor: current_admin).repair!
      if report[:fixes_count].positive?
        redirect_to admin_tournament_path(@tournament), notice: "Tournament health repair applied #{report[:fixes_count]} fix(es)."
      else
        redirect_to admin_tournament_path(@tournament), notice: "Tournament health check found no fixes to apply."
      end
    end

    private

    def set_tournament
      @tournament = Tournament.includes(:tournament_rounds, :tournament_entries).find(params[:id])
    end

    def tournament_params
      params.require(:tournament).permit(
        :name,
        :description,
        :status,
        :format,
        :game_key,
        :time_control,
        :rated,
        :max_players,
        :starts_at,
        :ends_at
      )
    end

    def available_presets
      available_presets_for(@tournament)
    end

    def available_presets_for(tournament)
      scope = TimeControlPreset.active.where(game_key: tournament.game_key)
      scope = scope.where(rated_allowed: true) if tournament.rated?
      scope.order(:category, :key)
    end

    def selected_time_control_params
      preset_ids = params.fetch(:allowed_time_control_preset_ids, [])
      locked_id = params[:locked_time_control_preset_id].presence
      allowed_ids = preset_ids.reject(&:blank?).uniq
      allowed_ids << locked_id if locked_id.present? && !allowed_ids.include?(locked_id)
      [ allowed_ids, locked_id ]
    end

    def valid_time_control_ids(tournament, allowed_ids)
      available_presets_for(tournament).where(id: allowed_ids).pluck(:id)
    end

    def validate_time_control_selection(tournament, selected_ids, locked_id)
      valid_ids = valid_time_control_ids(tournament, selected_ids)
      if valid_ids.sort != selected_ids.sort
        tournament.errors.add(:base, "One or more selected presets are invalid for this tournament.")
        return false
      end
      if locked_id.present? && !valid_ids.include?(locked_id)
        tournament.errors.add(:locked_time_control_preset_id, "is invalid for this tournament.")
        return false
      end
      true
    end

    def sync_tournament_time_controls!(tournament, selected_ids, locked_id)
      tournament.update!(locked_time_control_preset_id: locked_id)
      tournament.tournament_time_control_presets.where.not(time_control_preset_id: selected_ids).delete_all
      selected_ids.each do |preset_id|
        tournament.tournament_time_control_presets.find_or_create_by!(time_control_preset_id: preset_id)
      end
    end

    def prepare_form_time_controls
      @available_presets = available_presets_for(@tournament)
      ids, locked = selected_time_control_params
      if params.key?(:allowed_time_control_preset_ids) || params.key?(:locked_time_control_preset_id)
        @selected_preset_ids = ids
        @locked_preset_id = locked
      else
        @selected_preset_ids = @tournament.allowed_time_control_presets.pluck(:id)
        @locked_preset_id = @tournament.locked_time_control_preset_id
      end
    end

    def notification_stats
      logs = AuditLog.where(auditable: @tournament, action: [ "tournament.notified", "tournament.notification_failed" ])
      {
        sent: logs.where(action: "tournament.notified").count,
        failed: logs.where(action: "tournament.notification_failed").count
      }
    end

    def notification_events
      logs = AuditLog.where(auditable: @tournament, action: [ "tournament.notified", "tournament.notification_failed" ])
        .order(created_at: :desc)
        .limit(200)

      grouped = logs.group_by { |log| [ log.metadata["agent_id"].to_s, log.metadata["event"].to_s ] }
      agent_ids = grouped.keys.map(&:first).reject(&:blank?)
      agents_by_id = Agent.where(id: agent_ids).index_by { |agent| agent.id.to_s }
      grouped.map do |(agent_id, event), entries|
        latest = entries.first
        {
          agent: agents_by_id[agent_id],
          event: event.presence || "-",
          status: latest.action == "tournament.notified" ? "success" : "failed",
          error: latest.metadata["error"],
          at: latest.created_at
        }
      end.sort_by { |row| row[:at] }.reverse
    end
  end
end

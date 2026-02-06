class TournamentNotifyAgentsJob < ApplicationJob
  queue_as :default
  retry_on TournamentNotificationService::DeliveryError, wait: :polynomially_longer, attempts: 5

  def perform(tournament_id:, event:, agent_ids:, payload: {})
    tournament = Tournament.find_by(id: tournament_id)
    return unless tournament

    if agent_ids.length > 1
      agent_ids.each do |agent_id|
        self.class.perform_later(
          tournament_id: tournament_id,
          event: event,
          agent_ids: [ agent_id ],
          payload: payload
        )
      end
      return
    end

    TournamentNotificationService.new(
      tournament: tournament,
      event: event,
      agent_ids: agent_ids,
      payload: payload,
      raise_on_failure: true
    ).call
  end
end

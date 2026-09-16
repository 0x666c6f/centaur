module Api
  module V1
    class ScheduledTasksController < Api::BaseController
      def show
        response.headers["Cache-Control"] = "no-store"
        task = ScheduledTask.find_by_oid!(params[:id])
        delivery_policy = SlackDeliveryPolicy.new(task.author)
        principal = Principal.find_by(
          foreign_id: ConsoleUserPrincipalProvisioner.foreign_id_for(task.author),
          kind: :console_user,
          console_user_id: task.author_id
        )

        render json: {
          data: {
            id: task.oid,
            enabled: task.enabled?,
            author_active: task.author.active?,
            principal: principal&.foreign_id,
            delivery_channel: task.delivery_channel,
            delivery_allowed: delivery_policy.allowed?(task.delivery_channel)
          }
        }
      end
    end
  end
end

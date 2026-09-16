module Api
  module V1
    class ScheduledTaskExecutionsController < Api::BaseController
      def show
        task = ScheduledTask.find_by_oid(params[:id])
        principal = Principal.find_by(foreign_id: params.require(:principal))
        channel = params.require(:channel)

        response.headers["Cache-Control"] = "no-store"
        render json: { data: task.present? && task.executable_by?(principal, channel) }
      end
    end
  end
end

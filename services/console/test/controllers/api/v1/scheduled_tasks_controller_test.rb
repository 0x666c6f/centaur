require "test_helper"

module Api
  module V1
    class ScheduledTasksControllerTest < ActionDispatch::IntegrationTest
      setup do
        @author = users(:acme_admin)
        @author.user_identities.create!(
          provider: "slack",
          subject: "U0123456789",
          team_id: "T0123456789"
        )
        @task = ScheduledTask.create!(
          name: "Incident reminder",
          prompt: "Notify when recovered",
          author: @author,
          delivery_channel: "C0123456789",
          cron_expression: "*/5 * * * *",
          enabled: true
        )
        @path = "/api/v1/scheduled_tasks/#{@task.oid}"
      end

      test "returns current task execution state without task content" do
        get @path, headers: auth_headers

        assert_response :ok
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_equal(
          {
            "id" => @task.oid,
            "enabled" => true,
            "author_active" => true,
            "principal" => @task.execution_principal.foreign_id,
            "delivery_channel" => "C0123456789",
            "delivery_allowed" => true
          },
          response.parsed_body.fetch("data")
        )
        assert_not_includes response.body, @task.prompt
      end

      test "returns current disabled author and delivery state" do
        @task.update!(enabled: false)
        @author.update!(status: :disabled)

        get @path, headers: auth_headers(token: "iak_globex-ci-token")

        assert_response :ok
        assert_equal false, response.parsed_body.dig("data", "enabled")
        assert_equal false, response.parsed_body.dig("data", "author_active")
      end

      test "returns not found after deletion" do
        @task.destroy!

        get @path, headers: auth_headers

        assert_response :not_found
      end

      test "requires an active admin API key" do
        get @path
        assert_response :unauthorized

        get @path, headers: auth_headers(token: "iak_member-token")
        assert_response :forbidden
      end

      private

      def auth_headers(token: "iak_acme-ci-token")
        { "Authorization" => "Bearer #{token}" }
      end
    end
  end
end

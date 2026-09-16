require "test_helper"

module Api
  module V1
    class ScheduledTaskExecutionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @author = users(:acme_admin)
        @author.user_identities.create!(provider: "slack", subject: "U0123456789", team_id: "T0123456789")
        @task = ScheduledTask.create!(
          name: "Incident reminder", prompt: "Notify when recovered", author: @author,
          delivery_channel: "C0123456789", cron_expression: "*/5 * * * *", enabled: true
        )
        @principal = @task.execution_principal
        @path = "/api/v1/scheduled_tasks/#{@task.oid}/executable"
      end

      test "live checks observe disable and deletion without exposing task content" do
        check_task
        assert_response :ok
        assert_equal({ "data" => true }, response.parsed_body)
        assert_equal "no-store", response.headers["Cache-Control"]

        @task.update!(enabled: false)
        check_task
        assert_equal({ "data" => false }, response.parsed_body)

        @task.destroy!
        check_task
        assert_response :ok
        assert_equal({ "data" => false }, response.parsed_body)
      end

      test "requires an active admin API key" do
        get @path
        assert_response :unauthorized
        check_task(token: "iak_member-token")
        assert_response :forbidden
        check_task(token: "iak_disabled-token")
        assert_response :unauthorized
      end

      test "rejects another owner and a stale delivery destination" do
        check_task(principal: principals(:acme_channel).foreign_id)
        assert_equal false, response.parsed_body.fetch("data")
        check_task(channel: "C9999999999")
        assert_equal false, response.parsed_body.fetch("data")
        @author.update!(status: "disabled")
        check_task(token: "iak_globex-ci-token")
        assert_response :ok
        assert_equal false, response.parsed_body.fetch("data")
      end

      test "rechecks private channel membership before delivery" do
        channel = SlackBotChannel.create!(
          team_id: "T0123456789", bot_user_id: "U0999999999", channel_id: "G1111111111",
          name: "private-shared", private: true, active: true,
          member_user_ids: [ "U0123456789", "U0999999999" ]
        )
        @task.update!(delivery_channel: channel.channel_id)
        check_task(channel: channel.channel_id)
        assert_equal true, response.parsed_body.fetch("data")
        channel.update!(member_user_ids: [ "U0999999999" ])
        check_task(channel: channel.channel_id)
        assert_equal false, response.parsed_body.fetch("data")
      end

      private

      def check_task(token: "iak_acme-ci-token", principal: @principal.foreign_id, channel: @task.delivery_channel)
        get @path, params: { principal: principal, channel: channel },
            headers: { "Authorization" => "Bearer #{token}" }
      end
    end
  end
end

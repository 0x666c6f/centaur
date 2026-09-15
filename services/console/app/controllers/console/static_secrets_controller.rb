module Console
  # Create/edit form for StaticSecret: an inject XOR replace config (enforced by
  # the model), one optional source, and any number of request rules.
  class StaticSecretsController < BaseSecretsController
    include RuleParams

    def bulk_update
      secret_ids = Array(params[:secret_ids]).uniq
      if secret_ids.empty?
        return redirect_to console_secrets_path, alert: "Select at least one static secret."
      end

      enabled = case params[:operation]
      when "enable" then true
      when "disable" then false
      else
        return redirect_to console_secrets_path, alert: "Choose a valid bulk action."
      end

      secrets = secret_ids.map { |id| StaticSecret.find_by_oid!(id) }
      StaticSecret.transaction { secrets.each { |secret| secret.update!(enabled: enabled) } }

      status = enabled ? "enabled" : "disabled"
      redirect_to console_secrets_path, notice: "#{secrets.size} static #{"secret".pluralize(secrets.size)} #{status}."
    end

    private

    def model
      StaticSecret
    end

    def kind
      "static"
    end

    def assign_form(secret)
      assign_identity(secret)
      st = params.fetch(:static, ActionController::Parameters.new)
      secret.kind = st[:kind].presence || CredentialProfiles::Registry::CUSTOM_KIND
      secret.enabled = ActiveModel::Type::Boolean.new.cast(st[:enabled]) if st.key?(:enabled)
      if st[:mode] == "replace"
        secret.inject_config = nil
        secret.replace_config = replace_config(st)
      else
        secret.replace_config = nil
        secret.inject_config = inject_config(st)
      end
      secret.source = build_source
      assign_rules(secret)
      secret.rules = secret.apply_kind_defaults(rules: secret.rules)
    end

    def inject_config(st)
      cfg = {}
      cfg["header"] = st[:header].strip if st[:header].present?
      cfg["query_param"] = st[:query_param].strip if st[:query_param].present?
      cfg["formatter"] = st[:formatter] if st[:formatter].present?
      cfg.presence
    end

    def replace_config(st)
      cfg = { "proxy_value" => st[:proxy_value].to_s }
      headers = st[:match_headers].to_s.split(",").map(&:strip).reject(&:blank?)
      cfg["match_headers"] = headers if headers.any?
      %w[match_body match_path match_query require].each do |flag|
        cfg[flag] = true if ActiveModel::Type::Boolean.new.cast(st[flag])
      end
      cfg
    end
  end
end

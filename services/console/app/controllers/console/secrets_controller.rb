module Console
  # Mutations for grants from the secret detail page. The read-only show action
  # lives on ConsoleController; this controller only handles granting a displayed
  # secret to roles and revoking those role grants.
  class SecretsController < ApplicationController
    include SecretKinds

    layout "console"

    before_action :require_admin
    before_action :set_secret, only: %i[grant_role revoke_role_grant]

    def bulk_update
      secret_refs = Array(params[:secret_refs]).uniq
      if secret_refs.empty?
        return redirect_to console_secrets_path, alert: "Select at least one secret."
      end

      enabled = case params[:operation]
      when "enable" then true
      when "disable" then false
      else
        return redirect_to console_secrets_path, alert: "Choose a valid bulk action."
      end

      secrets = secret_refs.map do |ref|
        kind, separator, id = ref.partition(":")
        cfg = SECRET_KINDS[kind]
        raise ActiveRecord::RecordNotFound if separator.blank? || cfg.nil?

        cfg[:model].find_by_oid!(id)
      end
      ApplicationRecord.transaction { secrets.each { |secret| secret.update_attribute(:enabled, enabled) } }

      status = enabled ? "enabled" : "disabled"
      redirect_to console_secrets_path,
                  notice: "#{secrets.size} #{"secret".pluralize(secrets.size)} #{status}."
    end

    def grant_role
      role = Role.find_by_oid!(params[:role_id])
      Grant.create_with(created_by: current_user)
           .find_or_create_by!(role: role, grantable_assoc => @secret)
      redirect_to console_secret_path(@kind, @secret.oid),
                  notice: "Assigned secret to #{role_label(role)}."
    rescue ActiveRecord::RecordNotUnique
      # A concurrent submit already created the grant; the end state is what the
      # operator asked for, so report success rather than 500.
      redirect_to console_secret_path(@kind, @secret.oid),
                  notice: "Assigned secret to #{role_label(role)}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to console_secret_path(@kind, @secret.oid), alert: e.record.errors.full_messages.to_sentence
    end

    def revoke_role_grant
      grant = Grant.where(grantable_assoc => @secret)
                   .where.not(role_id: nil)
                   .find_by_oid!(params[:grant_id])
      grant.destroy!
      redirect_to console_secret_path(@kind, @secret.oid), notice: "Unassigned secret from role."
    end

    private

    def set_secret
      @kind = params[:kind]
      cfg = SECRET_KINDS[@kind]
      return render plain: "secret not found", status: :not_found unless cfg
      @secret = cfg[:model].find_by_oid!(params[:id])
    end

    def grantable_assoc
      @secret.class.name.underscore.to_sym
    end

    def role_label(role)
      role.name.presence || role.foreign_id.presence || role.oid
    end
  end
end

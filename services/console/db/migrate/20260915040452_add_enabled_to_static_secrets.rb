class AddEnabledToStaticSecrets < ActiveRecord::Migration[8.1]
  def change
    add_column :static_secrets, :enabled, :boolean, default: true, null: false
  end
end

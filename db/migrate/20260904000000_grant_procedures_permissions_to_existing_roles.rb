# frozen_string_literal: true

# Backfills `procedures.*` permissions to the system roles (Kaiabí custom
# feature, evo-ai-crm-community's ProceduresController — not part of upstream
# evolution-foundation).
#
# `procedures` was never registered in ResourceActionsConfig, so Settings >
# Roles never offered a checkbox to grant it and no role — not even
# super_admin — ever held any `procedures.*` key in production. Fresh installs
# pick the keys up from db/seeds/rbac.rb; an already-bootstrapped install runs
# `db:migrate` without `db:seed`, so it needs this data migration instead.
#
# Split "use" vs "manage", same shape as macros/message_templates in this
# release: the agent role uses procedures in the chat (read + send to
# customer) but does not manage them; managing (create/update/delete/publish/
# visibility/share) belongs to account_owner and super_admin.
class GrantProceduresPermissionsToExistingRoles < ActiveRecord::Migration[7.1]
  MANAGE_PERMISSIONS = %w[
    procedures.read
    procedures.create
    procedures.update
    procedures.delete
    procedures.publish
    procedures.manage_visibility
    procedures.send_to_customer
    procedures.share
    procedures.write
  ].freeze

  USE_PERMISSIONS = %w[
    procedures.read
    procedures.send_to_customer
  ].freeze

  GRANTS = {
    'super_admin' => MANAGE_PERMISSIONS,
    'account_owner' => MANAGE_PERMISSIONS,
    'agent' => USE_PERMISSIONS
  }.freeze

  def up
    return unless ActiveRecord::Base.connection.table_exists?(:roles)
    return unless ActiveRecord::Base.connection.table_exists?(:role_permissions_actions)

    GRANTS.each do |role_key, permission_keys|
      role = Role.find_by(key: role_key)
      next unless role

      permission_keys.each do |permission_key|
        next if role.role_permissions_actions.exists?(permission_key: permission_key)

        role.role_permissions_actions.create!(permission_key: permission_key)
      end
    end
  end

  def down
    return unless ActiveRecord::Base.connection.table_exists?(:roles)
    return unless ActiveRecord::Base.connection.table_exists?(:role_permissions_actions)

    GRANTS.each do |role_key, permission_keys|
      role = Role.find_by(key: role_key)
      next unless role

      role.role_permissions_actions.where(permission_key: permission_keys).destroy_all
    end
  end
end

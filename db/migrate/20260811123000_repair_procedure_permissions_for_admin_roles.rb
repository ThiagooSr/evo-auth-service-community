# frozen_string_literal: true

# Idempotent repair for installations that loaded the procedures catalog but did
# not receive the admin role grants during the first rollout.
class RepairProcedurePermissionsForAdminRoles < ActiveRecord::Migration[7.1]
  PERMISSIONS = %w[
    procedures.read
    procedures.create
    procedures.update
    procedures.delete
    procedures.publish
    procedures.share
    procedures.send_to_customer
    procedures.manage_visibility
    procedures.write
  ].freeze

  ROLE_KEYS = %w[super_admin account_owner].freeze

  def up
    return unless ActiveRecord::Base.connection.table_exists?(:roles)

    ROLE_KEYS.each do |role_key|
      role = Role.find_by(key: role_key)
      next unless role

      PERMISSIONS.each do |permission_key|
        role.role_permissions_actions.find_or_create_by!(permission_key: permission_key)
      end
    end
  end

  def down
    # No-op: this is a repair migration and should not revoke explicit grants.
  end
end

# frozen_string_literal: true

# Backfills the new `procedures.*` permissions to already-bootstrapped
# administrator roles. Manager/custom roles can be granted through the role
# editor after the catalog is visible.
class AddProcedurePermissionsToAdminRoles < ActiveRecord::Migration[7.1]
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

  ROLE_KEYS = %w[super_admin account_owner administrator admin].freeze

  def up
    return unless ActiveRecord::Base.connection.table_exists?(:roles)

    ROLE_KEYS.each do |role_key|
      role = Role.find_by(key: role_key)
      next unless role

      PERMISSIONS.each do |permission_key|
        next if role.role_permissions_actions.exists?(permission_key: permission_key)

        role.role_permissions_actions.create!(permission_key: permission_key)
      end
    end
  end

  def down
    return unless ActiveRecord::Base.connection.table_exists?(:roles)

    ROLE_KEYS.each do |role_key|
      role = Role.find_by(key: role_key)
      next unless role

      role.role_permissions_actions.where(permission_key: PERMISSIONS).destroy_all
    end
  end
end

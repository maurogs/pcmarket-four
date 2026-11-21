module Admin
  # User moderation rules. Suspension keeps the account but blocks sign-in and
  # hides listings through the active-owner scope; a ban additionally archives
  # every listing. Role changes protect the acting admin and the last admin.
  class UserModeration
    class Error < StandardError; end

    class << self
      def suspend(user, reason: nil)
        user.update!(status: :suspended, suspension_reason: reason, suspended_at: Time.current)
      end

      def unsuspend(user)
        user.update!(status: :active, suspension_reason: nil, suspended_at: nil)
      end

      def ban(user, reason: nil)
        user.transaction do
          user.listings.update_all(status: Listing.statuses[:archived], updated_at: Time.current)
          user.update!(status: :banned, suspension_reason: reason, suspended_at: Time.current)
        end
      end

      def unban(user)
        user.update!(status: :active, suspension_reason: nil, suspended_at: nil)
      end

      def change_role(user, new_role, actor:)
        raise Error, :invalid_role unless User.roles.key?(new_role.to_s)
        raise Error, :self_change if user.id == actor.id
        raise Error, :last_admin if demoting_last_admin?(user, new_role)

        user.update!(role: new_role)
      end

      private

      def demoting_last_admin?(user, new_role)
        return false unless user.admin?
        return false if new_role.to_s == "admin"

        User.admin.where.not(id: user.id).none?
      end
    end
  end
end

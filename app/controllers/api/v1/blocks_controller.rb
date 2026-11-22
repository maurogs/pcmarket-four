module Api
  module V1
    class BlocksController < BaseController
      before_action :authenticate!

      def create
        user = User.find(params[:user_id] || params.dig(:block, :blocked_id))

        if user.id == current_user.id
          return render_error("forbidden", t("messaging.blocks.cannot_block_self"),
                              status: :unprocessable_entity)
        end

        block = current_user.blocks_made.find_or_create_by!(blocked: user)
        @block = block
        render :create, formats: :json, status: :created
      end

      def destroy
        current_user.blocks_made.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end

class BlocksController < ApplicationController
  before_action :authenticate_user!

  def index
    redirect_to conversations_path(tab: "blocked")
  end

  def create
    user = User.find(params[:user_id].presence || params.dig(:block, :blocked_id))
    if user.id == current_user.id
      redirect_to conversations_path(tab: "blocked"), alert: t("messaging.blocks.cannot_block_self")
      return
    end

    current_user.blocks_made.find_or_create_by!(blocked: user)
    redirect_to conversations_path(tab: "blocked"), notice: t("messaging.blocks.blocked", name: user.display_name)
  end

  def destroy
    block = current_user.blocks_made.find(params[:id])
    name = block.blocked.display_name
    block.destroy!
    redirect_to conversations_path(tab: "blocked"), notice: t("messaging.blocks.unblocked", name: name)
  end
end

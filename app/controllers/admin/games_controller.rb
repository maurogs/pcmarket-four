module Admin
  class GamesController < BaseController
    before_action :set_game, only: %i[show edit update destroy]

    def index
      authorize_admin!(Game, :index?)

      @games = Game.ordered
    end

    def show
      authorize_admin!(@game, :show?)
      redirect_to edit_admin_game_path(@game)
    end

    def new
      authorize_admin!(Game, :new?)

      @game = Game.new(active: true, position: Game.maximum(:position).to_i + 1)
    end

    def create
      authorize_admin!(Game, :create?)

      @game = Game.new(game_params)
      if @game.save
        audit!("game.created", @game)
        redirect_to admin_games_path, notice: t("admin.games.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_admin!(@game, :edit?)
    end

    def update
      authorize_admin!(@game, :update?)

      if @game.update(game_params)
        audit!("game.updated", @game)
        redirect_to admin_games_path, notice: t("admin.games.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@game, :destroy?)

      @game.destroy!
      audit!("game.deleted", @game, changeset: { "slug" => @game.slug })
      redirect_to admin_games_path, notice: t("admin.games.deleted")
    end

    private

    def set_game
      @game = Game.find_by(slug: params[:id]) || Game.find(params[:id])
    end

    def game_params
      params.require(:game).permit(:slug, :name, :position, :active)
    end
  end
end

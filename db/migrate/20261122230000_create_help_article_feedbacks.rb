class CreateHelpArticleFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :help_article_feedbacks do |t|
      t.references :help_article, null: false, foreign_key: true
      t.boolean :helpful, null: false
      t.string :session_id, null: false
      t.timestamps
    end

    add_index :help_article_feedbacks, %i[help_article_id session_id], unique: true,
              name: "index_help_article_feedbacks_on_article_and_session"
  end
end

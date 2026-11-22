class AddTokenDigestToApiTokens < ActiveRecord::Migration[8.1]
  def up
    add_column :api_tokens, :token_digest, :string

    ApiToken.reset_column_information
    ApiToken.find_each do |token|
      token.update_column(:token_digest, Digest::SHA256.hexdigest(token.token.to_s))
    end

    change_column_null :api_tokens, :token, true
    add_index :api_tokens, :token_digest, unique: true
  end

  def down
    remove_index :api_tokens, :token_digest
    change_column_null :api_tokens, :token, false
    remove_column :api_tokens, :token_digest
  end
end

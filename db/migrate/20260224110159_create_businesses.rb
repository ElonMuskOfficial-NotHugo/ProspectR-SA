class CreateBusinesses < ActiveRecord::Migration[8.0]
  def change
    create_table :businesses do |t|
      t.string :name,        null: false
      t.string :category
      t.string :phone
      t.string :email
      t.string :address
      t.string :city
      t.string :province
      t.string :website_url
      t.string :source,      null: false, default: 'manual'
      t.boolean :needs_audit, null: false, default: true
      t.datetime :scraped_at

      t.timestamps
    end

    add_index :businesses, :source
    add_index :businesses, :city
    add_index :businesses, :province
    add_index :businesses, :needs_audit
    add_index :businesses, [:name, :city], unique: true
  end
end

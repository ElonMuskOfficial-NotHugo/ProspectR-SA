class CreateAuditResults < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_results do |t|
      t.references :business,          null: false, foreign_key: true
      t.boolean    :has_website,       null: false, default: false
      t.boolean    :has_ssl,           null: false, default: false
      t.boolean    :is_mobile_friendly, null: false, default: false
      t.string     :cms_detected
      t.integer    :load_time_ms
      t.integer    :copyright_year
      t.integer    :score,             null: false, default: 0
      t.text       :issues
      t.datetime   :audited_at

      t.timestamps
    end

    add_index :audit_results, :score
    add_index :audit_results, :has_website
    add_index :audit_results, :audited_at
  end
end

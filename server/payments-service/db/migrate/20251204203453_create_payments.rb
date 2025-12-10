class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments, id: :uuid do |t|
      # Foreign keys
      t.uuid :user_id, null: false
      t.uuid :appointment_id

      # Payment details
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: "USD", null: false
      t.integer :status, default: 0, null: false
      t.integer :payment_method

      # Stripe integration
      t.string :stripe_payment_intent_id
      t.string :stripe_charge_id

      # Additional information
      t.string :description
      t.datetime :paid_at
      t.text :failure_reason

      t.timestamps
    end

    # Indexes for better query performance
    add_index :payments, :user_id
    add_index :payments, :appointment_id
    add_index :payments, :status
    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :created_at
    add_index :payments, [ :user_id, :status ]
  end
end

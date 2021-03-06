# == Schema Information
#
# Table name: barcode_items
#
#  id               :bigint(8)        not null, primary key
#  value            :string
#  barcodeable_id   :integer
#  quantity         :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  organization_id  :integer
#  global           :boolean          default(FALSE)
#  barcodeable_type :string           default("Item")
#

class BarcodeItem < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :barcodeable, polymorphic: true, dependent: :destroy, counter_cache: :barcode_count

  validates :organization, presence: true, unless: proc { |b| b.global? }
  validates :value, presence: true
  validate  :unique_barcode_value
  validates :quantity, :barcodeable, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }

  include Filterable
  default_scope { order("global ASC, created_at ASC") }

  scope :barcodeable_id, ->(barcodeable_id) { where(barcodeable_id: barcodeable_id) }
  # Because it's a polymorphic association, we have to do this join manually.
  scope :by_item_partner_key, ->(partner_key) { joins("INNER JOIN items ON items.id = barcode_items.barcodeable_id").where(barcodeable_type: "Item", items: { partner_key: partner_key }) }
  scope :by_base_item_partner_key, ->(partner_key) { joins("INNER JOIN base_items ON base_items.id = barcode_items.barcodeable_id").where(barcodeable_type: "BaseItem", base_items: { partner_key: partner_key }) }
  scope :by_value, ->(value) { where(value: value) }
  scope :organization_barcodes_with_globals, ->(organization) { where(global: true).or(where(organization_id: organization, global: false)) }
  scope :include_global, ->(global) { where(global: [false, global]) }
  scope :for_csv_export, ->(organization) {
    where(organization: organization)
      .includes(:barcodeable)
  }
  scope :global, -> { where(global: true) }

  alias_attribute :item, :barcodeable
  alias_attribute :base_item, :barcodeable

  def to_h
    {
      barcodeable_id: barcodeable_id,
      barcodeable_type: barcodeable_type,
      quantity: quantity
    }
  end

  def self.csv_export_headers
    ["Item Type", "Quantity in the Box", "Barcode"]
  end

  def csv_export_attributes
    [
      barcodeable.name,
      quantity,
      value
    ]
  end

  private

  def unique_barcode_value
    if (global? && BarcodeItem.where.not(id: id).find_by(value: value, global: true)) ||
       (!global? && BarcodeItem.where.not(id: id).find_by(value: value, organization: organization))
      errors.add(:value, "That barcode value already exists")
    end
  end
end

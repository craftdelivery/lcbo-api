Product.where('limited_time_offer_savings_in_cents > ?', 0)

# Queries

Product.where("price_per_liter_in_cents > ?",0).where.not(:is_discontinued=>true).where.not(:is_dead=>true).order(:price_per_liter_in_cents).select("id, name, price_per_liter_in_cents, price_in_cents, regular_price_in_cents, volume_in_milliliters, updated_at")
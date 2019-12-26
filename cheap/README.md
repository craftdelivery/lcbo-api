## LCBO Beers by price per liter

## From a fork of the LCBO API

https://github.com/craftdelivery/lcbo-api

## Rails Query

```
  Product
    .where(:primary_category=>"Beer")
    .where.not("producer_name like ?", "%Saké%")
    .where.not("producer_name like ?", "%Sake%")
    .where.not("name like ?", "%Sake%")
    .where.not("primary_category like ?", "%Sake%")
    .where.not(:secondary_category=>"Sake")
    .where.not("name like ?", "%Saké%")
    .where.not("primary_category like ?", "%Saké%")
    .where.not(:secondary_category=>"Saké")
    .where("price_per_liter_in_cents > ?",0)
    .where.not(:is_discontinued=>true)
    .where("alcohol_content > ?", 100)
    .where.not(:is_dead=>true)
    .order(:price_per_liter_in_cents)
    .select("id, name, price_per_liter_in_cents, price_in_cents, regular_price_in_cents, volume_in_milliliters, alcohol_content, primary_category, secondary_category, producer_name, updated_at")
```

### Sake
LCBO API considered Sake to be beer so we're filtering it out...

## CURL
curl http://localhost:3000/cheap > beer.json

## csvkit

pip install csvkit

in2csv beer.json > beer.csv
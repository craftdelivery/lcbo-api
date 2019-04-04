module LCBO
  class ProductParser < Parser
    def before_parse
      return if xml.xpath('//product').length == 1
      raise LCBO::NotFoundError, "product XML contains no product data"
    end

    field :id do
      if (id = lookup(:itemNumber))
        id.to_i
      else
        raise LCBO::DafuqError, "expected product to have ID"
      end
    end

    field :name do
      if (name = lookup(:itemName))
        util.titlecase(name)
      else
        raise LCBO::DafuqError, "expected product to have a name"
      end
    end

    field :tags do
      util.tagify(
        name,
        primary_category,
        secondary_category,
        origin,
        producer_name,
        package_unit_type
      )
    end

    field :price_in_cents do
      val = lookup(:price)

      if val && val.start_with?('$')
        (val.sub('$', '').to_f * 100).to_i
      else
        0
      end
    end

    field :upc do
      lookup :upcNumber
    end

    field :scc do
      lookup :sccNumber
    end

    field :regular_price_in_cents do
      if has_limited_time_offer
        (lookup(:ltoRegularPrice).sub('$', '').to_f * 100).to_i
      else
        price_in_cents
      end
    end

    field :limited_time_offer_savings_in_cents do
      if has_limited_time_offer
        regular_price_in_cents - price_in_cents
      else
        0
      end
    end

    field :limited_time_offer_ends_on do
      if has_limited_time_offer
        util.parse_date(lookup(:ltoExpiration))
      else
        nil
      end
    end

    field :bonus_reward_miles do
      if has_bonus_reward_miles
        lookup(:amBonusMiles).to_i
      else
        0
      end
    end

    field :bonus_reward_miles_ends_on do
      if has_bonus_reward_miles
        util.parse_date(lookup(:amExpiration))
      else
        nil
      end
    end

    field :stock_type do
      lookup(:stockType).upcase
    end

    field :primary_category do
      lookup(:liquorType)
    end

    field :secondary_category do
      lookup(:categoryName)
    end

    field :tertiary_category do
      lookup(:subCategoryName)
    end

    field :origin do
      "#{lookup :producingCountry}, #{lookup :producingRegion}".
        gsub('/Californie', '').
        gsub('Bosnia\'Hercegovina', 'Bosnia and Herzegovina').
        gsub('Is. Of', 'Island of').
        gsub('Italy Quality', 'Italy').
        gsub('Usa-', '').
        gsub(', Rep. Of', '').
        gsub('&', 'and').
        gsub('Region Not Specified, ', '').
        split(',').
        map { |s| s.strip }.
        reject { |s| s == '' }.
        uniq.
        join(', ')
    end

    def package_data
      @package_data ||= util.parse_package(package)
    end

    field :package do
      size = lookup(:productSize)
      package = lookup(:sellingPackage)

      if (size == 'N/A') || size.blank?
        nil
      elsif package.present?
        size + ' ' + package
      else
        nil
      end
    end

    field :package_unit_type do
      package_data[:unit_type]
    end

    field :package_unit_volume_in_milliliters do
      package_data[:unit_volume]
    end

    field :total_package_units do
      package_data[:total_units]
    end

    field :volume_in_milliliters do
      package_data[:package_volume]
    end

    field :alcohol_content do
      val = lookup(:alcoholPercentage)

      if val && val.end_with?('%')
        (val.sub('%', '').to_f * 100).to_i
      else
        0
      end
    end

    field :price_per_liter_of_alcohol_in_cents do
      if alcohol_content > 0 && volume_in_milliliters > 0
        alc_frac = alcohol_content.to_f / 1000.0
        alc_vol  = (volume_in_milliliters.to_f / 1000.0) * alc_frac
        (price_in_cents.to_f / alc_vol).to_i
      else
        0
      end
    end

    field :price_per_liter_in_cents do
      if volume_in_milliliters > 0
        (price_in_cents.to_f / (volume_in_milliliters.to_f / 1000.0)).to_i
      else
        0
      end
    end

    field :style do
      lookup(:wineStyle)
    end

    field :style_flavour do
      lookup(:styleFlavour)
    end

    field :style_body do
      lookup(:styleBody)
    end

    field :sugar_content do
      lookup(:sweetnessDescriptor)
    end

    field :sugar_in_grams_per_liter do
      val = lookup(:sugarContent)

      if val && val.end_with?('g/L')
        val.sub('g/L', '').to_i
      else
        nil
      end
    end

    field :producer_name do
      val = lookup(:producer)

      if !val || val == 'N/A'
        nil
      else
        util.titlecase(val)
      end
    end

    field :varietal do
      lookup(:wineVarietal)
    end

    field :released_on do
      val = lookup(:releaseDate)

      if val == 'N/A'
        nil
      else
        util.parse_date(val)
      end
    end

    field :is_discontinued do
      lookup(:isDiscontinued) == 'true'
    end

    field :has_limited_time_offer do
      lookup(:lto) == 'Y'
    end

    field :has_bonus_reward_miles do
      lookup(:am) == 'Y'
    end

    field :has_value_added_promotion do
      lookup(:vao) == 'Y'
    end

    field :value_added_promotion_ends_on do
      if has_value_added_promotion
        util.parse_date(lookup(:vaoExpiration))
      else
        nil
      end
    end

    field :value_added_promotion_description do
      if has_value_added_promotion
        lookup(:vaoDescription)
      else
        nil
      end
    end

    field :is_seasonal do
      lookup(:isLimited) == 'true'
    end

    field :is_vqa do
      lookup(:vqa) == 'Y'
    end

    field :is_kosher do
      lookup(:kosher) == 'Y'
    end

    field :description do
      lookup(:itemDescription)
    end

    field :serving_suggestion do
      lookup(:pairings)
    end

    field :tasting_note do
      lookup(:tastingNotes)
    end
  end
end

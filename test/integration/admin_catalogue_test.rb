require "test_helper"

class AdminCatalogueTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end


  test "all phase 6C admin screens render" do
    get admin_filter_definitions_path(locale: :es)
    assert_response :success
    get new_admin_filter_definition_path(locale: :es)
    assert_response :success
    get edit_admin_filter_definition_path(filter_definitions(:cpu_brand), locale: :es)
    assert_response :success

    get admin_country_regions_path(countries(:spain), locale: :es)
    assert_response :success
    post admin_country_regions_path(countries(:spain), locale: :es),
         params: { region: { name: "Galicia", code: "GA" } }
    assert_redirected_to admin_country_regions_path(countries(:spain), locale: :es)
    assert Region.exists?(country_code: "ES", name: "Galicia")

    get admin_games_path(locale: :es)
    assert_response :success
    get new_admin_game_path(locale: :es)
    assert_response :success
    get edit_admin_game_path(games(:fortnite), locale: :es)
    assert_response :success

    get admin_legal_pages_path(locale: :es)
    assert_response :success
    get new_admin_legal_page_path(locale: :es)
    assert_response :success

    get new_admin_help_article_path(locale: :es)
    assert_response :success

    get admin_audit_log_path(admin_audit_logs(:listing_approved), locale: :es)
    assert_response :success
    assert_match "status", response.body
  end

  test "games and help articles update and delete" do
    game = games(:fortnite)
    patch admin_game_path(game, locale: :es), params: { game: { name: "Fortnite Battle Royale", active: "1" } }
    assert_redirected_to admin_games_path(locale: :es)
    assert_equal "Fortnite Battle Royale", game.reload.name

    article = HelpArticle.create!(slug: "sell-safely", category: :safety, position: 2,
                                  titles: { es: "Vende seguro", en: "Sell safely" },
                                  bodies: { es: "<p>A</p>", en: "<p>B</p>" })
    patch admin_help_article_path(article, locale: :es), params: {
      help_article: { published: "0", titles: { es: "Vende con seguridad", en: "Sell safely" } }
    }
    assert_redirected_to edit_admin_help_article_path(article, locale: :es)
    assert_not article.reload.published?

    assert_difference -> { HelpArticle.count }, -1 do
      delete admin_help_article_path(article, locale: :es)
    end
    assert_redirected_to admin_help_articles_path(locale: :es)
  end

  test "legal page create and copy translation" do
    assert_difference -> { LegalPage.count }, 1 do
      post admin_legal_pages_path(locale: :es), params: {
        legal_page: { slug: "returns", country_code: "ES", locale: "en",
                      title: "Returns", body: "<p>Returns policy</p>", published: "1" }
      }
    end
    page = LegalPage.find_by!(slug: "returns", country_code: "ES", locale: "en")
    get edit_admin_legal_page_path(id: page.id, locale: :es, copy_from: legal_pages(:terms_spain).id)
    assert_response :success
    assert_match I18n.t("admin.legal_pages.copy.title"), response.body
  end

  test "category index, new and edit render" do
    get admin_categories_path(locale: :es)
    assert_response :success
    assert_select "[data-sortable-id]", minimum: 1

    get new_admin_category_path(locale: :es)
    assert_response :success
    assert_select "#category_names_en"

    get edit_admin_category_path(categories(:graphics_cards), locale: :es)
    assert_response :success
    assert_select "#category_seo_es"
  end

  test "category create, update and delete guard" do
    assert_difference -> { Category.count }, 1 do
      post admin_categories_path(locale: :es), params: {
        category: {
          names: { es: "Monitores", en: "Monitors", fr: "Écrans" },
          slug: "monitors-test", parent_id: "", active: "1", show_in_menu: "1"
        }
      }
    end
    category = Category.find_by!(slug: "monitors-test")
    assert_equal "Monitors", category.names["en"]

    patch admin_category_path(category, locale: :es), params: {
      category: { names: { es: "Pantallas", en: "Displays" }, slug: "displays-test" }
    }
    assert_redirected_to edit_admin_category_path(category.reload, locale: :es)
    assert_equal "Displays", category.names["en"]

    assert_no_difference -> { Category.count } do
      delete admin_category_path(categories(:graphics_cards), locale: :es)
    end
    assert_redirected_to admin_categories_path(locale: :es)
    assert_match(/No se puede eliminar/, flash[:alert])
  end

  test "category positions reorder siblings and bust the menu cache" do
    first = categories(:graphics_cards)
    second = categories(:cpus)
    MenuBuilder.new(locale: :es).call

    patch admin_category_positions_path(locale: :es), params: {
      parent_id: categories(:components).id,
      ordered_ids: [ second.id, first.id ].join(",")
    }
    assert_response :no_content
    assert_operator second.reload.position, :<, first.reload.position

    first.update!(names: first.names.merge("es" => "GPUs nuevas"))
    menu = MenuBuilder.new(locale: :es).call
    names = menu.flat_map { |root| root["children"].map { |child| child["name"] } }
    assert_includes names, "GPUs nuevas"
  end

  test "filter create, key immutability and option creation" do
    assert_difference -> { FilterDefinition.count }, 1 do
      post admin_filter_definitions_path(locale: :es), params: {
        filter_definition: {
          key: "screen_size", input_type: "select", unit: "in", position: 9, active: "1",
          names: { es: "Tamaño", en: "Screen size" }
        }
      }
    end
    filter = FilterDefinition.find_by!(key: "screen_size")

    patch admin_filter_definition_path(filter, locale: :es), params: {
      filter_definition: { key: "other_key", names: { es: "Otro", en: "Other" } }
    }
    assert_equal "screen_size", filter.reload.key

    assert_difference -> { filter.filter_options.count }, 1 do
      post admin_filter_definition_filter_options_path(filter, locale: :es), params: {
        filter_option: { value: "27", labels: { es: "27 pulgadas", en: "27 inches" } }
      }
    end
  end

  test "filter option merge rewrites listing specs and removes the source" do
    filter = filter_definitions(:cpu_brand)
    option = filter.filter_options.create!(value: "ryzen", labels: { en: "Ryzen" },
                                           position: 3)
    listing = listings(:published_gpu)
    listing.update!(specs: listing.specs.merge("cpu_brand" => "ryzen"))

    post admin_filter_definition_merge_path(filter, locale: :es), params: {
      source_value: "ryzen", target_value: "amd"
    }

    assert_redirected_to edit_admin_filter_definition_path(filter, locale: :es)
    assert_equal "amd", listing.reload.specs["cpu_brand"]
    assert_not FilterOption.exists?(option.id)
  end

  test "settings update casts values, audits changes and maintenance mode answers 503" do
    patch admin_save_settings_path(locale: :es), params: {
      settings: { max_images_per_listing: "9", commission_percent: "7,5", site_name: "PCMarket ES" }
    }
    assert_redirected_to admin_settings_path(locale: :es)
    assert_equal 9, Setting.get("max_images_per_listing")
    assert_equal BigDecimal("7.5"), Setting.get("commission_percent")
    assert AdminAuditLog.exists?(action: "settings.updated")

    Setting.set("maintenance_mode", true)
    delete destroy_user_session_path(locale: :es)

    get root_path(locale: :es)
    assert_response :service_unavailable
    assert_match I18n.t("maintenance.title"), response.body

    get "/up"
    assert_response :success

    sign_in users(:admin)
    get root_path(locale: :es)
    assert_response :success
    assert_match I18n.t("maintenance.staff_banner"), response.body

    get admin_settings_path(locale: :es)
    assert_response :success
  ensure
    Setting.set("maintenance_mode", false)
  end

  test "country page renders the launch checklist and blocks GBP until enabled" do
    get admin_countries_path(locale: :es)
    assert_response :success
    assert_match I18n.t("admin.countries.checklist.title"), response.body
    assert_match I18n.t("admin.countries.checklist.legal_pages"), response.body

    gb = countries(:spain).class.find_or_create_by!(code: "GB") do |country|
      country.name_key = "countries.GB"
      country.currency = "GBP"
      country.default_locale = "en"
    end

    patch admin_country_path(gb, locale: :es), params: { country: { enabled: "1" } }
    assert_redirected_to admin_countries_path(locale: :es)
    assert_not gb.reload.enabled?
    assert_match I18n.t("admin.countries.currency_blocked", currency: "GBP"), flash[:alert]

    Setting.set("allow_non_eur_countries", true)
    patch admin_country_path(gb, locale: :es), params: { country: { enabled: "1" } }
    assert gb.reload.enabled?
  end

  test "legal page versioning and sanitisation" do
    page = legal_pages(:terms_spain)
    original_version = page.version

    patch admin_legal_page_path(page, locale: :es), params: {
      legal_page: { title: "Términos actualizados",
                    body: "<h2>Nuevo</h2><script>alert(1)</script><p>Texto</p>" }
    }
    assert_redirected_to edit_admin_legal_page_path(page, locale: :es)
    page.reload
    assert_equal original_version + 1, page.version
    assert_not_includes page.body_html, "<script>"
    assert_includes page.body_html, "<h2>Nuevo</h2>"
  end

  test "games reorder and help article CRUD" do
    first = games(:fortnite)
    second = games(:counter_strike_2)
    patch admin_game_positions_path(locale: :es),
          params: { ordered_ids: [ second.id, first.id ].join(",") }
    assert_response :no_content
    assert_operator second.reload.position, :<, first.reload.position

    get admin_help_articles_path(locale: :es)
    assert_response :success

    assert_difference -> { HelpArticle.count }, 1 do
      post admin_help_articles_path(locale: :es), params: {
        help_article: {
          slug: "how-to-buy", category: "buying", position: 1, published: "1",
          titles: { es: "Cómo comprar", en: "How to buy" },
          bodies: { es: "<p>Guía</p>", en: "<p>Guide</p>" }
        }
      }
    end
    article = HelpArticle.find_by!(slug: "how-to-buy")
    assert_equal "Cómo comprar", article.title(:es)

    get edit_admin_help_article_path(article, locale: :es)
    assert_response :success
  end

  test "feature request approval features the listing and is hidden when disabled" do
    listing = listings(:published_gpu)
    listing.update!(featured_until: nil, labels: listing.labels - [ "featured" ])
    request = FeatureRequest.create!(listing: listing, user: users(:seller), days: 7,
                                     price_cents: 499, status: :pending)

    get admin_feature_requests_path(locale: :es)
    assert_response :success

    assert_difference -> { AdminAuditLog.where(action: "feature_request.approved").count }, 1 do
      post admin_feature_request_approval_path(request, locale: :es)
    end
    assert_redirected_to admin_feature_requests_path(locale: :es)
    assert request.reload.active?
    assert_operator listing.reload.featured_until, :>, Time.current
    assert_includes listing.labels, "featured"

    Setting.set("featured_listings_enabled", false)
    sign_in users(:seller)
    get new_seller_feature_request_path(locale: :es, listing_id: listing.id)
    assert_redirected_to seller_listings_path(locale: :es)
  end

  test "newsletter counts, filtering and CSV export" do
    get admin_newsletter_subscribers_path(locale: :es)
    assert_response :success
    assert_match newsletter_subscribers(:confirmed_subscriber).email, response.body

    get admin_newsletter_export_path(locale: :es, format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "subscriber@example.com", response.body
  end

  test "moderators can read but not mutate phase 6C resources" do
    delete destroy_user_session_path(locale: :es)
    sign_in users(:moderator)

    get admin_categories_path(locale: :es)
    assert_response :success
    get admin_settings_path(locale: :es)
    assert_response :success
    get admin_countries_path(locale: :es)
    assert_response :success

    assert_no_difference -> { Category.count } do
      post admin_categories_path(locale: :es), params: {
        category: { names: { es: "No", en: "No" }, slug: "nope" }
      }
    end
    assert_redirected_to root_path(locale: :es)

    patch admin_save_settings_path(locale: :es), params: { settings: { site_name: "Nope" } }
    assert_redirected_to root_path(locale: :es)
    assert_not_equal "Nope", Setting.get("site_name")
  end
end

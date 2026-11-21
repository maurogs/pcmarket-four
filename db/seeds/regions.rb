region_data = {
  "ES" => [
    [ "01", "Álava" ], [ "02", "Albacete" ], [ "03", "Alicante" ], [ "04", "Almería" ],
    [ "05", "Ávila" ], [ "06", "Badajoz" ], [ "07", "Illes Balears" ], [ "08", "Barcelona" ],
    [ "09", "Burgos" ], [ "10", "Cáceres" ], [ "11", "Cádiz" ], [ "12", "Castellón" ],
    [ "13", "Ciudad Real" ], [ "14", "Córdoba" ], [ "15", "A Coruña" ], [ "16", "Cuenca" ],
    [ "17", "Girona" ], [ "18", "Granada" ], [ "19", "Guadalajara" ], [ "20", "Gipuzkoa" ],
    [ "21", "Huelva" ], [ "22", "Huesca" ], [ "23", "Jaén" ], [ "24", "León" ],
    [ "25", "Lleida" ], [ "26", "La Rioja" ], [ "27", "Lugo" ], [ "28", "Madrid" ],
    [ "29", "Málaga" ], [ "30", "Murcia" ], [ "31", "Navarra" ], [ "32", "Ourense" ],
    [ "33", "Asturias" ], [ "34", "Palencia" ], [ "35", "Las Palmas" ], [ "36", "Pontevedra" ],
    [ "37", "Salamanca" ], [ "38", "Santa Cruz de Tenerife" ], [ "39", "Cantabria" ],
    [ "40", "Segovia" ], [ "41", "Sevilla" ], [ "42", "Soria" ], [ "43", "Tarragona" ],
    [ "44", "Teruel" ], [ "45", "Toledo" ], [ "46", "Valencia" ], [ "47", "Valladolid" ],
    [ "48", "Bizkaia" ], [ "49", "Zamora" ], [ "50", "Zaragoza" ], [ "51", "Ceuta" ],
    [ "52", "Melilla" ]
  ],
  "FR" => [
    [ "84", "Auvergne-Rhône-Alpes" ], [ "27", "Bourgogne-Franche-Comté" ],
    [ "53", "Bretagne" ], [ "24", "Centre-Val de Loire" ], [ "94", "Corse" ],
    [ "44", "Grand Est" ], [ "32", "Hauts-de-France" ], [ "11", "Île-de-France" ],
    [ "28", "Normandie" ], [ "75", "Nouvelle-Aquitaine" ], [ "76", "Occitanie" ],
    [ "52", "Pays de la Loire" ], [ "93", "Provence-Alpes-Côte d'Azur" ]
  ],
  "GB" => [
    [ "ENG", "England" ], [ "SCT", "Scotland" ], [ "WLS", "Wales" ],
    [ "NIR", "Northern Ireland" ]
  ],
  "DE" => [
    [ "DE-BW", "Baden-Württemberg" ], [ "DE-BY", "Bayern" ], [ "DE-BE", "Berlin" ],
    [ "DE-BB", "Brandenburg" ], [ "DE-HB", "Bremen" ], [ "DE-HH", "Hamburg" ],
    [ "DE-HE", "Hessen" ], [ "DE-MV", "Mecklenburg-Vorpommern" ],
    [ "DE-NI", "Niedersachsen" ], [ "DE-NW", "Nordrhein-Westfalen" ],
    [ "DE-RP", "Rheinland-Pfalz" ], [ "DE-SL", "Saarland" ], [ "DE-SN", "Sachsen" ],
    [ "DE-ST", "Sachsen-Anhalt" ], [ "DE-SH", "Schleswig-Holstein" ],
    [ "DE-TH", "Thüringen" ]
  ],
  "IT" => [
    [ "65", "Abruzzo" ], [ "77", "Basilicata" ], [ "78", "Calabria" ], [ "72", "Campania" ],
    [ "45", "Emilia-Romagna" ], [ "36", "Friuli-Venezia Giulia" ], [ "62", "Lazio" ],
    [ "42", "Liguria" ], [ "25", "Lombardia" ], [ "57", "Marche" ], [ "67", "Molise" ],
    [ "21", "Piemonte" ], [ "75", "Puglia" ], [ "88", "Sardegna" ], [ "82", "Sicilia" ],
    [ "52", "Toscana" ], [ "32", "Trentino-Alto Adige" ], [ "55", "Umbria" ],
    [ "23", "Valle d'Aosta" ], [ "34", "Veneto" ]
  ],
  "PT" => [
    [ "01", "Aveiro" ], [ "02", "Beja" ], [ "03", "Braga" ], [ "04", "Bragança" ],
    [ "05", "Castelo Branco" ], [ "06", "Coimbra" ], [ "07", "Évora" ], [ "08", "Faro" ],
    [ "09", "Guarda" ], [ "10", "Leiria" ], [ "11", "Lisboa" ], [ "12", "Portalegre" ],
    [ "13", "Porto" ], [ "14", "Santarém" ], [ "15", "Setúbal" ], [ "16", "Viana do Castelo" ],
    [ "17", "Vila Real" ], [ "18", "Viseu" ], [ "20", "Açores" ], [ "30", "Madeira" ]
  ]
}.freeze

region_data.each do |country_code, regions|
  regions.each do |code, name|
    region = Region.find_or_initialize_by(country_code: country_code, name: name)
    region.code = code
    region.save!
  end
end

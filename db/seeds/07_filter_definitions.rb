# Admin-editable filter definitions part 1/2 (CPU, cooler, GPU, memory,
# storage). Part 2 continues with 07b; options in 08_filter_options.rb.

# Sidebar group translations (method so the next seed file can reuse it).
def filter_group(name)
  case name
  when "cpu" then t6("CPU", "CPU", "CPU", "CPU", "CPU", "CPU")
  when "cooler" then t6("Cooling", "Refrigeración", "Refroidissement", "Kühlung", "Raffreddamento", "Refrigeração")
  when "gpu" then t6("Graphics", "Gráficos", "Graphismes", "Grafik", "Grafica", "Gráficos")
  when "memory" then t6("Memory", "Memoria", "Mémoire", "Arbeitsspeicher", "Memoria", "Memória")
  when "storage" then t6("Storage", "Almacenamiento", "Stockage", "Speicher", "Archiviazione", "Armazenamento")
  when "motherboard" then t6("Motherboard", "Placa base", "Carte mère", "Mainboard", "Scheda madre", "Placa-mãe")
  when "case" then t6("Case", "Caja", "Boîtier", "Gehäuse", "Case", "Gabinete")
  when "power" then t6("Power", "Alimentación", "Alimentation", "Stromversorgung", "Alimentazione", "Alimentação")
  when "display" then t6("Display", "Pantalla", "Écran", "Display", "Display", "Ecrã")
  when "device" then t6("Device", "Dispositivo", "Appareil", "Gerät", "Dispositivo", "Dispositivo")
  when "platform" then t6("Platform", "Plataforma", "Plateforme", "Plattform", "Piattaforma", "Plataforma")
  when "peripherals" then t6("Peripherals", "Periféricos", "Périphériques", "Peripherie", "Periferiche", "Periféricos")
  when "connectivity" then t6("Connectivity", "Conectividad", "Connectivité", "Konnektivität", "Connettività", "Conetividade")
  when "features" then t6("Features", "Características", "Fonctionnalités", "Funktionen", "Funzionalità", "Funcionalidades")
  else raise ArgumentError, "unknown filter group #{name.inspect}"
  end
end

def seed_filter_definition(key, group, label, input_type, position)
  seed_record(FilterDefinition, {
    key: key,
    group_translations: filter_group(group),
    label_translations: label,
    input_type: input_type,
    position: position,
    active: true
  }, %i[key])
end

definitions = [
  [ "cpu_brand", "cpu", t6("CPU brand", "Marca de CPU", "Marque du CPU", "CPU-Marke", "Marca CPU", "Marca de CPU"), "multi_select" ],
  [ "cpu_core_count", "cpu", t6("Core count", "Número de núcleos", "Nombre de cœurs", "Kernanzahl", "Numero di core", "Número de núcleos"), "multi_select" ],
  [ "cpu_socket", "cpu", t6("Socket", "Socket", "Socket", "Sockel", "Socket", "Socket"), "multi_select" ],
  [ "cpu_cooler_brand", "cooler", t6("Cooler brand", "Marca de disipador", "Marque du ventirad", "Kühler-Marke", "Marca del dissipatore", "Marca do disipador"), "multi_select" ],
  [ "cpu_cooler_type", "cooler", t6("Cooling type", "Tipo de refrigeración", "Type de refroidissement", "Kühlungsart", "Tipo di raffreddamento", "Tipo de refrigeração"), "multi_select" ],
  [ "gpu_chipset", "gpu", t6("GPU brand", "Marca de GPU", "Marque du GPU", "GPU-Marke", "Marca GPU", "Marca de GPU"), "multi_select" ],
  [ "gpu_model", "gpu", t6("GPU model", "Modelo de GPU", "Modèle de GPU", "GPU-Modell", "Modello GPU", "Modelo de GPU"), "multi_select" ],
  [ "gpu_memory", "gpu", t6("Graphics memory", "Memoria gráfica", "Mémoire vidéo", "Grafikspeicher", "Memoria video", "Memória gráfica"), "multi_select" ],
  [ "memory_capacity", "memory", t6("Capacity", "Capacidad", "Capacité", "Kapazität", "Capacità", "Capacidade"), "multi_select" ],
  [ "memory_brand", "memory", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ],
  [ "memory_type", "memory", t6("Generation", "Generación", "Génération", "Generation", "Generazione", "Geração"), "multi_select" ],
  [ "memory_form_factor", "memory", t6("Form factor", "Formato", "Format", "Bauform", "Formato", "Formato"), "multi_select" ],
  [ "storage_capacity", "storage", t6("Capacity", "Capacidad", "Capacité", "Kapazität", "Capacità", "Capacidade"), "multi_select" ],
  [ "storage_interface", "storage", t6("Interface", "Interfaz", "Interface", "Schnittstelle", "Interfaccia", "Interface"), "multi_select" ],
  [ "storage_form_factor", "storage", t6("Form factor", "Formato", "Format", "Bauform", "Formato", "Formato"), "multi_select" ],
  [ "storage_brand", "storage", t6("Brand", "Marca", "Marque", "Marke", "Marca", "Marca"), "multi_select" ]
].freeze

definitions.each_with_index do |(key, group, label, input_type), index|
  seed_filter_definition(key, group, label, input_type, index + 1)
end

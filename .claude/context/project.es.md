# PCMarket — Contexto del proyecto

## Estado

Fase 6B completada: operaciones de administración para pedidos y conciliación
de pagos, disputas, denuncias y moderación de reseñas, con enlaces desde el
panel y contadores cacheados en la barra lateral. La base del panel de la fase
6A (panel, moderación de anuncios, usuarios, tiendas, auditoría y suplantación)
sigue intacta. El chat interno de la fase 5 con conversaciones, contadores de no
leídos y mensajes en tiempo real, ofertas con precio reservado en la cesta,
bloqueos y avisos de seguridad en los mensajes; notificaciones a seguidores,
alertas instantáneas y resumen diario de búsquedas guardadas y alertas de bajada
de precio en favoritos siguen intactos. El ciclo de vida de pedidos de la fase
4B (pagado, enviado, entregado, completado, cancelado, en disputa y
reembolsado), las pantallas de gestión del vendedor, la confirmación de entrega,
las disputas y las reseñas del comprador, las notificaciones de pedido con envío
de correos y la actualización del contador en tiempo real siguen intactos. El
descubrimiento (fase 2B), la creación de anuncios (fase 3A) y el pago (fase 4A)
no han cambiado. Las pantallas de catálogo, contenido, marketing y ajustes
quedan para la fase 6C y enlazan a páginas traducidas de «próximamente».

## Estado de las fases

| Fase | Alcance | Estado |
|---|---|---|
| 1 | Base, localización y sistema de diseño | Completada |
| 2B | Descubrimiento, búsqueda, anuncios, tiendas, favoritos y acceso | Completada |
| 3A | Creación de anuncios y panel del vendedor | Completada |
| 3B | Área del vendedor y ajustes de cuenta | Completada |
| 4A | Cesta, pago y cobros | Completada |
| 4B | Ciclo de pedidos y gestión del vendedor | Completada |
| 5 | Mensajería, ofertas, seguidores y alertas de búsquedas | Completada |
| 6A | Base de administración, panel, moderación, usuarios y tiendas | Completada |
| 6B | Pedidos, pagos, disputas, denuncias y reseñas de administración | Completada |

## Stack

- Ruby 4.0.9, Rails 8.1.4, PostgreSQL 16
- Hotwire (Turbo, Stimulus), import maps, Propshaft, Tailwind CSS 4
- Devise 5 (database authenticatable, registerable, recoverable, rememberable,
  validatable, confirmable, trackable, lockable, omniauthable)
- Pundit (autorización), Pagy 9 (paginación)
- pg_search (tsearch + trigram), FriendlyId, Ancestry
- rack-attack, meta-tags
- Stripe (sesiones Checkout y webhooks firmados); WebMock en las pruebas
- Minitest con fixtures

## Decisiones de arquitectura

### Localización

- `available_locales`: `es`, `en`, `fr`, `de`, `it`, `pt`; por defecto `es`;
  alternativas `es`, `en`.
- Todas las rutas excepto `/up`, `/robots.txt` y `/sitemap.xml` están dentro de
  `scope "(:locale)", locale: /es|en|fr|de|it|pt/`.
- `ApplicationController#switch_locale` valida `params[:locale]` y envuelve
  cada petición en `I18n.with_locale`.
- Los callbacks OmniAuth de Devise viven fuera del ámbito de idioma porque
  Devise no admite callbacks OmniAuth bajo un segmento dinámico.
- Los archivos de idioma se dividen por dominio (`models`, `home`, `layout`,
  `listings`, `pages`, `newsletter`, `errors`, `common`, `countries`, `cart`,
  `checkout`, `orders`, `notifications`, `messaging`, `admin`); cada clave existe en los
  seis idiomas. `test/i18n/locale_parity_test.rb` exige paridad.
- El inglés es inglés británico (favourite, colour, authorised).
- Los selectores de idioma del pie y del cajón conservan la ruta y la consulta
  actuales.

### Modelo de datos

- Claves primarias bigint, claves foráneas reales, `null: false` donde el
  dominio exige un valor e índices en cada FK y en las columnas de filtrado y
  ordenación.
- El dinero se guarda en céntimos enteros en EUR; los códigos de país son
  cadenas ISO alpha-2 (`ES`, `FR`, `GB`, `DE`, `IT`, `PT`).
- `pg_trgm` y `unaccent` están habilitados para la búsqueda.
- `Setting` guarda filas tipadas clave/valor, cachea en `settings/v1/<key>` y
  recurre a `Setting::DEFAULTS`. La caché se invalida al guardar o destruir.
- Los borrados lógicos usan `users.deleted_at`; `User.visible` limita a cuentas
  activas y no eliminadas.
- Los nombres de usuario se generan como `Adjective-Animal#1234` a partir de
  listas de palabras integradas.
- El flujo de `Listing` son métodos tipo máquina de estados
  (`submit_for_review!`, `approve!`, `reject!`, `pause!`, `resume!`,
  `mark_sold!`), sin AASM.
- `Listing.visible` exige estado publicado, stock, propietario activo y país
  habilitado. `Listing.on_sale` y `Listing.recently_sold` alimentan las
  secciones de la portada.
- `Listing::LABELS` y `Listing::TAGS` contienen los vocabularios de etiquetas
  del mercado y del vendedor; ambos se traducen en `listings.labels.*` y
  `listings.tags.*`.
- Slugs: FriendlyId en `Store` (nombre), `Category` (nombre en inglés) y
  `Listing` (título, con historial mediante `friendly_id_slugs`).
- `Category.find_by_path_slugs` resuelve `/c/components/gpus`; `#path_slugs`
  devuelve la cadena de slugs.
- Las reseñas recalculan `stores.rating_avg`/`reviews_count` en `after_commit`.
- Los pedidos calculan subtotal, comisión (solo si está activa) y total en
  `Order#compute_totals!`. Los pedidos son compras del comprador: `buyer_id`
  puede ser nulo para invitados, `buyer_email` es obligatorio para invitados y
  cada pedido lleva `payment_method`, `locale`, `checkout_token` (único por
  vendedor), `guest_access_token` (has_secure_token), `terms_accepted_at` y
  `stock_restored_at`.
- El ciclo de vida del pedido es una máquina de estados de métodos
  transaccionales protegidos en `Order`: `mark_paid!`, `ship!`,
  `mark_ready_for_pickup!`, `confirm_delivery!`, `complete!`, `cancel!`,
  `open_dispute!`, `resolve_dispute!`, `refund!` y `flag_late_shipment!`. Cada
  transición bloquea la fila, valida el estado de origen y el actor, escribe un
  `OrderEvent` y envía notificaciones mediante `OrderNotifier`.
- `OrderEvent` guarda `order_id`, `actor_id` opcional, `kind`, `data` jsonb y
  `created_at`; las cronologías del comprador y del vendedor lo leen en orden
  cronológico. Los pedidos también llevan `disputed_at`, `refunded_at`,
  `refund_required` y `late_shipment_notified_at`.
- La cancelación repone el stock y vuelve a publicar los anuncios vendidos
  exactamente una vez mediante `stock_restored_at`. La finalización incrementa
  `stores.sales_count`. `Order` expone URL de seguimiento para diez
  transportistas y ayudantes para la ventana de inspección.
- `Notifier.call(user, kind, params:, url:)` crea una `Notification` y encola el
  correo de pedido correspondiente cuando `email_order_updates` está activo. Las
  notificaciones difunden reemplazos del contador en
  `turbo_stream_from user, :notifications`.
- `orders.number` procede de la secuencia PostgreSQL `order_number_seq` como
  `PCM-YYYY-NNNNNN`; la secuencia la crea una migración y se asegura de forma
  perezosa en bases de datos de prueba cargadas desde el esquema.
- Favoritos y seguidores usan contadores en caché.

### Datos de ejemplo

- `db/seeds.rb` carga `db/seeds/*.rb` en orden de dependencias: ajustes, países,
  regiones, categorías, filtros, juegos, páginas legales y datos de
  demostración.
- Cada archivo de datos es idempotente. Los datos de referencia usan
  `find_or_initialize_by` más `save!`; ejecutar los datos dos veces no produce
  duplicados.
- La taxonomía de categorías tiene dos niveles. Las categorías hoja contienen
  anuncios; las asignaciones de filtros de un padre se heredan mediante
  `Category#effective_filters`.
- Las categorías de la fase 1 que ya no forman parte de la taxonomía se eliminan
  solo cuando no contienen anuncios, de modo que nunca se destruyen datos de
  usuario.
- Los datos de demostración solo se crean en desarrollo; el administrador se
  crea en todos los entornos que no son producción.

### Sistema de diseño

- Tokens `@theme` de Tailwind v4 en `app/assets/tailwind/application.css`:
  teal de marca `--color-brand-50..950`, ámbar `--color-accent-*`, títulos en
  Space Grotesk, cuerpo en Inter, radio de tarjeta de 12 px y tokens de sombra
  compartidos.
- Modo oscuro por clase mediante `@custom-variant dark`; un script en línea de la
  cabecera aplica el tema guardado o preferido antes del pintado.
- Las primitivas de UI viven en `app/views/shared/` y en métodos de ayudante
  (`ui_button_classes`, `ui_badge_classes`, `ui_chip_classes`,
  `ui_input_classes`, `ui_card_classes`).
- Los iconos son SVG de Lucide incluidos en el proyecto y leídos por
  `ApplicationHelper#icon`.

### Navegación y diseño

- `MenuBuilder` cachea el menú gigante con una clave que contiene el idioma y
  `Category.maximum(:updated_at)`.
- Cabecera: fija, con desenfoque al desplazar, búsqueda con autocompletado,
  botón "Véndenoslo a PCMarket" tras un flag, contadores de favoritos,
  notificaciones, cesta y bandeja de entrada, menú de cuenta, selector de tema y
  menú gigante.
- El menú gigante se abre con 150 ms de intención al pasar o al hacer clic, se
  cierra al hacer clic fuera y con Escape, y muestra categorías hijas, enlaces
  rápidos por etiqueta y precio y tarjetas promocionales.
- En móvil se usa un cajón lateral izquierdo (trampa de foco, bloqueo de
  desplazamiento, Escape) y una barra inferior por debajo de 768 px.
- El consentimiento de cookies es un controlador Stimulus en `<body>`; las
  opciones se guardan en `cookie_consent` durante seis meses.
  `consent_given?(:analytics)` permite condicionar futuros scripts de terceros.

### Portada

- `HomeFeed` concentra todas las consultas de la portada y usa
  `Listing.visible.includes(:store, :category, images_attachments: :blob)`.
- Las secciones se cachean por idioma durante cinco minutos; las tarjetas de
  anuncio se cachean por fragmentos en `[listing, I18n.locale]` mientras el
  botón de favorito dependiente del visitante queda fuera de la caché.
- Secciones: carrusel principal, mosaicos promocionales, llamada al buscador de
  PC, compra por ambiente, filas con desplazamiento, franja de confianza,
  carrusel de reseñas con testimonios traducidos de reserva, llamada a vender y
  texto SEO.
- `listings/_card.html.erb` es la tarjeta compartida por portada, búsqueda y
  favoritos.

### Búsqueda y filtrado (fase 2B)

- `ListingSearch` (`app/services/listing_search.rb`) es el único punto de
  entrada para web, API y alertas de búsquedas guardadas. Normaliza parámetros,
  limita la consulta a 100 caracteres y la página a 100, y convierte entradas en
  euros a céntimos. Acepta `q`, `category`, `min_price`, `max_price`,
  `condition[]`, `labels[]`, `tags[]`, `f[key][]`, `region_id[]`, `shipping[]`,
  `free_shipping`, `on_sale`, `seller`, `sort` y `page`.
- Los filtros de especificaciones usan contención JSONB
  (`listings.specs @> '{"key":"value"}'`), con OR dentro de una clave y AND entre
  claves. Solo se aceptan claves de `FilterDefinition` efectivas para la
  categoría actual, lo que neutraliza intentos de inyección en claves de
  filtro.
- `Result` expone registros paginados (Pagy, 24 por página), total (cacheado
  60 s), chips de filtros activos con parámetros eliminables, recuentos de
  facetas para filtros de casilla efectivos y recuentos de estado.
- Las facetas se calculan con UNA consulta agrupada sobre
  `jsonb_each_text(listings.specs)` contra la relación filtrada por categoría,
  consulta, precio y estado (todo excepto los filtros de especificaciones),
  cacheadas 5 minutos por resumen de (categoría, q, precio, estado, claves de
  filtro). Las opciones con cero resultados se ocultan salvo que estén
  seleccionadas.
- La interfaz de búsqueda se ejecuta dentro de un único
  `turbo-frame#listing_results`; la barra lateral, la barra de herramientas, la
  cuadrícula y la paginación viven dentro, así que filtrar solo reemplaza el
  frame. Los formularios usan `data-turbo-action="advance"` para URL
  compartibles y compatibilidad con el botón Atrás. El controlador Stimulus
  `filters_controller` envía casillas y selects al instante y aplica 400 ms de
  retardo a texto y precio, mostrando tarjetas esqueleto. La hoja de filtros
  móvil contiene el mismo formulario parcial.
- Las páginas de categoría, `/search` y los anuncios de tienda reutilizan el
  mismo parcial de resultados. Las páginas de tienda pasan una relación base
  limitada a la tienda y un conmutador `include_sold`, y ocultan las secciones
  de especificaciones, etiquetas y región (modo `compact`).
- Índices añadidos para búsqueda: `(status, category_id, published_at DESC)`,
  `(status, price_cents)`, `(status, favorites_count DESC)`,
  `(status, store_id, published_at DESC)`, `(status, region_id, published_at
  DESC)` y un parcial `(status, published_at DESC)` para publicados con stock.
  Los índices GIN existentes cubren `specs`, `labels`, `tags` y trigram en
  título y descripción.
- Plan de consulta con 5.000 anuncios generados (revertido):
  `RAILS_ENV=test bin/rails db:test:prepare` y después
  `RAILS_ENV=test bin/rails runner script/search_explain.rb`. La consulta
  combinada de categoría + estado + precio + envío + especificaciones (1.917
  resultados) usa `Index Scan using index_listings_search_category` con el resto
  de predicados como filtros; planificación 1,7 ms, ejecución 13,5 ms, 238
  búferes compartidos para el escaneo de anuncios. El GIN
  `index_listings_on_specs` sigue disponible cuando el planificador prefiere la
  contención frente al índice compuesto.

### Detalle de anuncio, tiendas y favoritos (fase 2B)

- Las páginas de detalle usan una cuadrícula 7/5 en escritorio con una caja de
  compra fija, una galería Stimulus (deslizamiento con puntero, teclas de
  flecha, miniaturas, `<dialog>` lightbox) y una barra inferior fija de
  precio/CTA en móvil. Las imágenes usan variantes WebP con
  `resize_to_limit`; la primera es eager + `fetchpriority=high` y el resto
  perezosas.
- Los contadores de visitas usan un único `UPDATE` mediante
  `Listing.register_view!`, omiten bots y propietarios y recuerdan los últimos
  50 identificadores en la sesión (también usados para "vistos recientemente"
  en portada y detalle).
- Los slugs antiguos se resuelven mediante `friendly_id_slugs` y redirigen 301 a
  la URL actual. Los anuncios no visibles son 404 para extraños pero visibles
  para propietarios y personal con una franja de estado; los anuncios vendidos
  siguen siendo públicos y muestran la oferta de agotado.
- Datos estructurados: Product + Offer (precio, moneda, disponibilidad, estado
  del artículo), BreadcrumbList y aggregateRating de la tienda. Las páginas de
  búsqueda emiten BreadcrumbList + ItemList.
- Las páginas de tienda tienen cabecera con banner/logo, insignia de profesional
  o particular, datos de empresa/fiscales, aviso de vacaciones, pestañas
  (anuncios/acerca de/reseñas) cargadas mediante `turbo-frame#store-panel`, un
  conmutador `include_sold`, barras de distribución de reseñas, ordenación y
  reseñas paginadas con respuestas del vendedor.
- Los favoritos se alternan mediante Turbo Streams: `replace_all` actualiza
  todas las instancias de corazón de un anuncio, el contador se reemplaza por
  separado y las tarjetas se eliminan de la cuadrícula de favoritos. Un
  controlador Stimulus alterna el corazón de forma optimista y lo restaura si la
  petición falla. Las intenciones de invitados se guardan en la sesión, se
  completan tras iniciar sesión y después vuelven al anuncio.
- Seguir tiendas usa un contador en caché y reemplazo Turbo del botón y del
  número de seguidores.

### Cesta y autenticación (fase 2B)

- Las cestas de invitado usan un `cart_token` firmado permanente; las de usuario
  usan `user_id`. Un hook `after_authentication` de Warden fusiona los artículos
  de invitado en la cesta del usuario, limita cantidades por stock y elimina las
  filas de invitado.
- La creación de artículos de cesta rechaza anuncios propios y no visibles,
  limita la cantidad por stock y responde con Turbo Streams que actualizan el
  contador de cabecera y añaden un aviso. "Comprar ahora" añade el artículo y
  redirige a la cesta.
- Las vistas de Devise usan un diseño de dos columnas con testimonios rotativos.
  El registro exige la casilla de términos (`users.terms_accepted_at`), registra
  la aceptación de marketing y respeta `Setting registrations_enabled`. El
  enlace de acceso de la cabecera abre el mismo formulario dentro de un
  `<dialog>` en Turbo Frame con alternativa de página completa. En desarrollo,
  el correo se ve con `letter_opener` en `/letter_opener`.
- Las búsquedas guardadas se crean a partir de la cadena de consulta actual, se
  listan en `/saved_searches` y en la página de cuenta, y pueden alternar
  notificaciones con Turbo Streams. Las denuncias son una por usuario y anuncio.

### Creación de anuncios y panel del vendedor (fase 3A)

- El formulario del vendedor es una única página con cinco secciones (categoría,
  fotos, detalles, precio, entrega). `listing_form_controller` añade contadores,
  progreso, ordenación por arrastre, previsualización de archivos y validación
  de tipo/tamaño en cliente; el formulario sigue siendo usable sin JavaScript.
- El selector de categoría usa tarjetas `<details>` raíz y enlaces hoja. Un
  enlace hoja navega solo `turbo-frame#listing_specs` a
  `new_listing_path(category_id:)` / `edit_listing_path(category_id:)`, de modo
  que los campos ya escritos no se tocan. El frame lleva el
  `listing[category_id]` oculto.
- `ListingForm` es el único escritor del formulario del vendedor: asigna
  escalares, conserva especificaciones solo para las claves de filtro efectivas
  de la categoría (guardadas como cadenas), adjunta/elimina/reordena imágenes,
  fuerza cantidad 1 para vendedores particulares, exige imagen al enviar y aplica
  la transición borrador → pending_review/published.
- Las imágenes se suben mediante Active Storage direct uploads
  (`@rails/activestorage` fijado en el import map). El orden de visualización se
  guarda en `metadata["position"]` del blob y toda representación usa
  `Listing#ordered_images`.
- Las entradas de dinero usan atributos virtuales (`price=`, `original_price=`,
  `shipping_price=`) que aceptan `1.299,50`, `1299.50` y `1299`.
- Un anuncio creado sin tienda llama a `User#ensure_store!`, que crea una tienda
  individual con el nombre del usuario.
- Los anuncios publicados siguen activos tras editar precio, cantidad, envío o
  descripción. Los cambios de título, categoría o imágenes marcan
  `Listing#requires_re_review?` a partir de `saved_changes` y de los cambios de
  medios, y devuelven el anuncio a `pending_review` cuando la aprobación está
  activa.
- Destruir archiva (`status: archived`) cuando existen líneas de pedido y
  elimina definitivamente en caso contrario. Duplicar copia el anuncio como
  borrador y reutiliza los blobs de imagen.
- Rutas miembro anidadas modelan las acciones de ciclo de vida:
  `listing_submission` (enviar), `listing_pause` (POST pausar, DELETE
  reanudar) y `listing_sale` (marcar vendido). `Seller::ListingsController#index`
  filtra por estado con recuentos y búsqueda; las acciones masivas
  pausar/reanudar/eliminar pasan por `Seller::BulkListingActionsController` y el
  servicio `BulkListingAction`, que limita la acción permitida.
- El detalle del anuncio usa colocación de cuadrícula para que la caja de compra
  siga al título en móvil y quede junto a la galería en escritorio; la fila de
  estadísticas se ajusta por grupos con elementos `whitespace-nowrap`. El envío
  gratuito con envío activo muestra la etiqueta traducida "Envío gratis" en la
  caja de compra, las tarjetas y la sección de envío.

### Área del vendedor y ajustes de cuenta (fase 3B)

- `Seller::BaseController` aporta autenticación, el diseño `seller` y
  `seller_store` (`User#ensure_store!`). El diseño tiene una tarjeta de cabecera
  de tienda y navegación adaptable: barra lateral en escritorio y pestañas
  desplazables en móvil.
- `SellerDashboard` cachea una carga agregada durante 5 minutos por tienda y
  emite tarjetas KPI con variaciones de 30 días, un gráfico de pedidos SVG en
  línea renderizado en servidor (con `<title>/<desc>` accesibles y tabla
  visualmente oculta), enlaces de acción, completitud de tienda y anuncios
  recientes. Los agregados condicionales `FILTER` mantienen el panel por debajo
  de 30 consultas incluida la interfaz.
- Los ajustes del vendedor son recursos singulares: `seller/store`,
  `seller/store_policy`, `seller/vacation` y `seller/payout`. El logotipo
  (≤5 MB) y el banner (≤8 MB) aceptan JPEG/PNG/WebP;
  `image_preview_controller` previsualiza las subidas.
- `Store` usa el historial de FriendlyId. Los cambios de nombre archivan el slug
  anterior y las URL antiguas de tienda redirigen 301 al slug actual.
  `Store#completeness` pondera logotipo, descripción, ambas políticas y
  ubicación con 25 puntos cada uno.
- Las tiendas profesionales exigen `company_name` y `tax_id`; los identificadores
  fiscales españoles se validan con `SpanishTaxIdValidator` (NIF/NIE módulo 23,
  dígito de control CIF).
- El modo vacaciones mantiene visibles los anuncios pero desactiva la compra en
  la caja de compra y rechaza `CartItemsController#create` con un aviso
  traducido.
- Los pagos en línea no están implementados: `seller/payout` explica el modelo de
  pago por pedido y muestra un botón Stripe Connect desactivado.
- Los ajustes de cuenta son recursos singulares bajo `account`: perfil
  (`show/update`), contraseña, direcciones, preferencias de notificación,
  exportación de datos y eliminación. `Account::BaseController` aporta el
  diseño `account`.
- Las direcciones promueven la primera a predeterminada, limpian las demás
  dentro de la transacción de guardado y promueven una alternativa cuando se
  elimina la predeterminada.
- `users.notification_preferences` es un hash jsonb (verdadero por defecto salvo
  el boletín, que refleja `accepts_marketing`). `User#notify_by_email?` es la API
  de lectura; `User#update_notification_preferences!` es la de escritura.
- `UserDataExport` genera la descarga JSON de los artículos 15/20 del RGPD solo
  para el usuario autenticado. `User#soft_delete!` anonimiza correo, nombre de
  usuario y nombres, borra el avatar, archiva anuncios y conserva pedidos.
- Los cambios de correo pasan por Devise reconfirmable (`unconfirmed_email`);
  las contraseñas exigen la actual salvo en cuentas solo OAuth, que pueden
  establecer una.
- `ApplicationController#switch_locale` resuelve el idioma explícito, después el
  del usuario autenticado, después la mejor coincidencia de `Accept-Language` y
  por último el español. Seleccionar un idioma con sesión iniciada lo persiste en
  `users.locale`.

### Cesta, pago y cobros (fase 4A)

- `CartSummary` (`app/services/cart_summary.rb`) es el único modelo de lectura de
  la página de cesta, el contador de cabecera y el pago. Agrupa filas de cesta
  por vendedor y tienda, limita cantidades al stock actual, marca artículos
  vendidos/no disponibles/de vacaciones, excluye los no disponibles de los
  totales y devuelve envío por grupo (suma del envío de artículos, gratis o solo
  recogida).
- La página de cesta renderiza una tarjeta por tienda con miniaturas, estado y
  precio de los artículos, un selector de cantidad solo cuando el stock supera
  uno, eliminar y guardar en favoritos. La barra lateral muestra subtotal, envío,
  una nota interna de comisión de plataforma cuando las comisiones están activas
  (el comprador nunca la paga), total estimado, caja de protección del comprador
  y las llamadas al pago o acceso de invitado. `Setting checkout_enabled` oculta
  las llamadas y muestra el aviso traducido de desactivado.
- Las mutaciones de cesta (cantidad, eliminar, favorito) responden con Turbo
  Streams que reemplazan `#cart-groups`, `#cart-summary` y `#cart-count`.
  Guardar en favoritos es un recurso anidado `cart_item_favorite`.
- El pago es un recurso singular `checkout` con un `confirmation` anidado.
  `Checkout::Form` valida correo de contacto, envío o recogida por vendedor, la
  dirección de envío compartida (dirección guardada o campos escritos), país
  habilitado, prefijo de provincia/código postal español, disponibilidad de pago
  y ambas aceptaciones legales. La página usa cuatro pasos `<details>` con un
  pequeño controlador Stimulus que abre el siguiente.
- `Checkout::PlaceOrder` se ejecuta en una transacción: revalida el resumen,
  bloquea cada anuncio `FOR UPDATE` en orden de identificador, vuelve a
  comprobar visibilidad/stock, crea un pedido pending_payment por vendedor con
  instantáneas de título/precio, decrementa stock (marcando vendidos los de
  stock cero), guarda opcionalmente la dirección y vacía las filas compradas.
  `checkout_token` (campo oculto, único por vendedor) hace que un doble envío
  devuelva los pedidos originales.
- Los proveedores de pago implementan `start(orders, return_urls)` y
  `handle_webhook(request)`: `BankTransfer` (por defecto, IBAN/beneficiario/plazo
  desde ajustes), `CashOnPickup` (solo cuando todos los grupos son de recogida)
  y `Stripe` (sesión Checkout por pedido, metadatos con identificadores de
  pedido, webhook firmado, marcado pagado idempotente y reposición de stock al
  caducar). `Payments::Availability` calcula los métodos ofrecidos a partir de
  ajustes, la clave de Stripe y el estado de recogida.
- `ExpireUnpaidOrdersJob` se ejecuta cada hora en todos los entornos y cancela
  pedidos con transferencia pendientes de pago anteriores a
  `payment_deadline_days`, reponiendo stock y republicando anuncios agotados.
- La confirmación muestra números de pedido por vendedor, totales, instrucciones
  de pago, próximos pasos y enlaces de invitado.
  `OrderMailer#placed_buyer` y `#placed_seller` envían HTML + texto en el idioma
  del pedido; el correo del vendedor respeta `email_order_updates`.
- Los pedidos del comprador están en `/orders` (pestañas Todos/Por pagar/En
  curso/Completados/Cancelados, búsqueda por número/título) y
  `/orders/:number` (cronología de estado, artículos, tarjeta del vendedor,
  dirección de entrega, instrucciones de pago, totales). `OrderPolicy` solo
  permite compradores; los invitados usan el parámetro de consulta
  `guest_access_token`. `Orders::CancellationsController` permite al comprador
  cancelar un pedido impagado y repone el stock.
- Nuevos valores por defecto de ajustes: `payment_bank_transfer_enabled`,
  `bank_iban`, `bank_beneficiary`, `payment_deadline_days`, `stripe_enabled`.

### Ciclo de pedidos y gestión del vendedor (fase 4B)

- Las transiciones del ciclo de vida de `Order` son métodos de modelo
  transaccionales y protegidos. Administración puede marcar pagado, reembolsar y
  resolver disputas; los vendedores pueden marcar pagado el pago contra
  reembolso, enviar con un transportista de `Order::CARRIERS` y seguimiento
  (opcional solo para `other`), marcar listas las recogidas locales y cancelar
  pedidos pagados con indicador de reembolso. Los compradores confirman la
  recepción y abren disputas dentro de la ventana de inspección.
- `OrderNotifier` distribuye notificaciones en la aplicación y correos HTML/texto
  por idioma para eventos pagado, enviado, entregado, completado, cancelado,
  disputa, reembolso y envío tardío. Los compradores invitados reciben correo sin
  cuenta. El correo de disputa de administración va a `Setting.support_email`.
- Trabajos recurrentes de Solid Queue: `AutoDeliverOrdersJob` (enviados hace más
  de `auto_delivered_after_shipping_days`), `AutoCompleteOrdersJob` (entregados
  hace más de `inspection_window_days`, omitiendo disputas) y
  `LateShipmentReminderJob` (un recordatorio tras `seller_ship_deadline_days` y
  cancelación automática con reembolso al doble).
- Las acciones del comprador son recursos singulares anidados:
  `delivery_confirmation`, `dispute` (new/create con hasta cinco fotos), `review`
  y `cancellation`.
- El panel `/seller/orders` tiene pestañas (por enviar, esperando pago,
  enviados, completados incluidos entregados, cancelados/reembolsados,
  disputas), recuentos, búsqueda, tabla en escritorio/tarjetas en móvil,
  exportación CSV, página de pedido con dirección protegida por privacidad (solo
  pagados), línea de comisión cuando no es cero, pago neto, seguimiento,
  modales de envío/recogida/efectivo/cancelación, respuestas a reseñas y albarán
  optimizado para impresión en `/seller/orders/:id/packing_slip`.
- Los ingresos de `SellerDashboard` son `sum(total_cents - commission_cents)` de
  pedidos pagados, enviados, entregados y completados.
- Las reseñas exigen pedido completado, propiedad del comprador, una por pedido,
  un cuerpo de 20–1000 caracteres y ninguna palabra de
  `Setting blocked_words`. Los vendedores responden una vez y pueden editar esa
  respuesta. `reviews_enabled` oculta formularios del comprador, paneles de
  reseñas de tienda y secciones de reseñas del anuncio.
- Las notificaciones están en `/notifications` (no leídas primero, paginadas,
  marcar todas como leídas, lectura individual al hacer clic) y en una campana
  perezosa de cabecera en Turbo Frame con las últimas ocho.
  `Notification#after_create_commit` reemplaza el contador mediante
  `Turbo::StreamsChannel`.
- Nuevos valores por defecto de ajustes: `inspection_window_days` 2,
  `auto_complete_after_delivery_days` 2, `auto_delivered_after_shipping_days`
  14, `seller_ship_deadline_days` 3, `support_email` y `blocked_words`.

### Mensajería, ofertas y alertas (fase 5)

- `Conversation` es una conversación por `[anuncio, comprador, vendedor]`; las
  conversaciones sin anuncio cubren las entradas desde tienda y pedidos.
  `ConversationStarter` concentra las reglas: chat activo, sin auto-mensajes,
  sin bloqueo en ninguna dirección, visibilidad del anuncio, primer mensaje y
  primera oferta opcional.
- La bandeja está en `/inbox` con pestañas Chats, Ofertas, Archivadas y Usuarios
  bloqueados. En escritorio se muestra la lista y un
  `turbo-frame#conversation-thread` perezoso; en móvil se muestra la lista y
  después la conversación con un enlace de vuelta. Los contadores de no leídos
  los incrementa `Message` de forma atómica y los reinicia
  `Conversation#mark_read_for!`; `Conversation.broadcast_inbox_badge` mantiene
  vivo el contador de cabecera mediante `[user, :inbox]`.
- Los mensajes difunden `append` a `[conversation, user]` para ambos
  participantes, de modo que la alineación propio/otro es correcta. El
  compositor tiene área de texto autoajustable, Intro envía, Mayús+Intro añade
  una línea, máximo 2.000 caracteres y se desactiva con bloqueos, anuncios
  eliminados o chat desactivado. Los separadores de día usan el idioma de la
  petición.
- `MessageSafetyScanner` marca correos, teléfonos ES/EN, IBAN y frases de pago
  fuera de la plataforma (Bizum, PayPal Friends, Western Union, transferencias
  fuera del mercado). La marca se guarda en `messages.flagged` y muestra un aviso
  traducido al destinatario sin bloquear la entrega.
- `Message` limita a cada remitente a 30 mensajes cada 10 minutos.
- Las ofertas son mensajes `kind: offer` con límites (< precio del anuncio,
  ≥ 50 %, `accepts_offers`), caducidad de 48 horas y `ExpireOffersJob` cada diez
  minutos. `OfferResponse` acepta, rechaza o hace contraoferta; la contraoferta
  marca la anterior como rechazada y crea una nueva oferta pendiente. La
  aceptación escribe `cart_items.offer_price_cents`/`offer_expires_at` (24
  horas); `CartSummary` y `Checkout::PlaceOrder` guardan el precio de la oferta
  en `OrderItem`.
- Los bloqueos son una fila `Block` en cualquier dirección; la cabecera de la
  conversación bloquea o desbloquea y la bandeja lista a los usuarios
  bloqueados. Las denuncias amplían el `Report` polimórfico a conversaciones.
- `MessageNotifier` crea notificaciones para mensajes y ofertas nuevas y envía
  correos mediante `MessageMailer` respetando
  `email_messages`/`email_offers`; los correos de mensaje se limitan a uno por
  conversación y destinatario cada 15 minutos.
- Publicar un anuncio encola `NotifyFollowersJob` (solo notificación) y
  `SavedSearchAlertJob` (coincidencias instantáneas, prefiltro SQL por subárbol
  de categoría, precio y país, después `SavedSearch#matches?`; se excluye al
  propietario). `SavedSearchDigestJob` se ejecuta a diario a las 08:00
  Europe/Madrid para búsquedas con `frequency: daily`, agrupa hasta 20
  coincidencias por usuario y actualiza `last_notified_at`. Ambos respetan
  `email_saved_search_alerts` y `Setting saved_search_alerts_enabled`.
- `PriceDropAlertJob` avisa a los usuarios que tienen el anuncio en favoritos
  cuando baja el precio de un anuncio publicado y les envía correo si
  `email_price_drops_favourites` está activo.
- La gestión de búsquedas guardadas permite renombrar, elegir frecuencia
  (instantánea/diaria), activar o desactivar avisos, repetir la búsqueda y
  eliminar. `/account/following` lista las tiendas seguidas con sus últimos
  anuncios. `config.time_zone` es Europe/Madrid y las marcas de tiempo se siguen
  guardando en UTC.
- El ajuste `chat_enabled` ya existía; los nuevos tipos de notificación son
  `message_received`, `offer_received`, `offer_accepted`, `offer_declined`,
  `offer_countered`, `followed_store_listing`, `saved_search_match` y
  `price_drop_favourite`.

### Límites de rendimiento

- `ListingSearch::INCLUDES` precarga tienda, categoría, región, usuario y
  adjuntos/blobs de imágenes. Las tarjetas nunca llaman a `category.root` ni a
  `user.store`; los slugs raíz vienen de un `Category.root_slug_map` cacheado y
  los nombres de vendedor prefieren la tienda precargada.
- `MenuBuilder` obtiene raíces e hijos directos en dos consultas y construye
  rutas desde slugs sin recorrer la ascendencia.
- `Setting` cachea toda la pequeña tabla de ajustes bajo una clave.
- Las páginas de búsqueda anónimas envían `Cache-Control: public, max-age=60` y
  `fresh_when` sobre `[locale, params digest, Listing.maximum(:updated_at)]`; las
  páginas de anuncio usan `fresh_when` sobre
  `[listing, locale, store.updated_at]`.
- Protección contra N+1: `test/integration/search_performance_test.rb` renderiza
  una página de categoría con 24 anuncios y exige menos de 25 consultas SQL
  mediante `ActiveSupport::Notifications`.

### SEO y seguridad

- `ApplicationController#set_default_meta_tags` establece título, descripción,
  canónica, alternativas hreflang más `x-default`, Open Graph y Twitter.
- JSON-LD `Organization` + `WebSite` con `SearchAction` se emite una vez en el
  diseño.
- `/robots.txt` y `/sitemap.xml` los gestiona `SeoController` fuera del ámbito de
  idioma. `SitemapBuilder` cachea la salida una hora y divide en un índice de
  sitemaps a partir de 45.000 URL.
- Una CSP estricta basada en nonce permite recursos propios, Google Fonts,
  imágenes data/blob y el import map. `Permissions-Policy` y `Referrer-Policy`
  se establecen en `config/initializers/security_headers.rb`.
- Producción fuerza SSL y usa `solid_cache`; desarrollo usa `memory_store`,
  alternable con `bin/rails dev:cache`.

### Autorización

- `ApplicationController` incluye `Pundit::Authorization`; las peticiones no
  autorizadas redirigen atrás con `errors.not_authorized`.
- `ListingPolicy` permite a los propietarios editar/eliminar sus anuncios y a
  moderadores/administradores aprobar o rechazar. `ListingPolicy::Scope` oculta
  los anuncios no visibles al público.
- Las rutas de administración exigen `current_user.staff?`; los visitantes que no
  son personal se redirigen a la portada con un aviso traducido.

### Panel de administración (fase 6A)

- Todas las rutas de administración viven en el ámbito de idioma en
  `/:locale/admin`. `Admin::BaseController` autentica, exige
  `current_user.staff?`, usa el layout denso `admin` y expone el contador de
  moderación pendiente.
- La autorización usa políticas Pundit en `app/policies/admin/`
  (`Admin::ListingPolicy`, `Admin::UserPolicy`, `Admin::StorePolicy` y políticas
  pequeñas específicas). Los moderadores pueden moderar anuncios, usuarios y
  tiendas; las acciones destructivas (eliminar anuncios, expulsar, cambiar
  roles, suplantar y borrado RGPD) requieren administrador. Las peticiones no
  autorizadas redirigen atrás con `errors.not_authorized`.
- `Admin::Auditable` registra cada mutación en `admin_audit_logs` con
  administrador, acción, auditable polimórfico, un conjunto de cambios saneado
  (sin contraseñas ni tokens) y la IP. Los detalles de anuncio, usuario y tienda
  muestran el historial; `/admin/audit_logs` filtra por acción, administrador y
  recurso.
- El layout `admin` usa una barra lateral de escritorio que se contrae a iconos
  (`admin_sidebar_controller`, persistido en localStorage), se desliza fuera de
  pantalla en móvil, y una barra superior con búsqueda global, «Ver el sitio»,
  cambio de tema y el administrador actual.
- La búsqueda global (`Admin::GlobalSearch`) consulta usuarios (correo/usuario/
  nombre), anuncios (título/id), pedidos (número/id) y tiendas (nombre), y
  muestra una página de resultados agrupada.
- Los parciales del kit de administración viven en `app/views/admin/shared/`:
  tabla de datos con cabeceras ordenables permitidas, selector de 25/50/100 por
  página, paginación, barra de filtros, barra de acciones masivas, insignias de
  estado, tarjetas de métricas, estados vacíos, cabecera de detalle con menú de
  acciones y panel lateral de metadatos.
- `Admin::Dashboard` cachea una carga durante dos minutos: tendencias de KPI a
  siete días con comisión solo si es positiva, gráficos SVG en línea a 30 días
  (línea de registros, barras de pedidos, barras de las 10 categorías
  principales), últimos anuncios pendientes/pedidos/usuarios y un panel de salud
  (tareas fallidas y pendientes de Solid Queue si existen las tablas, bytes de
  Active Storage, `pg_database_size`). La acción y el marco quedan por debajo de
  40 consultas SQL.
- La cola de moderación lista anuncios `pending_review` de más antiguo a más
  nuevo con todas las imágenes, aviso de precio frente a la mediana de la
  categoría por debajo del 40 % (posible estafa), análisis de la descripción con
  `MessageSafetyScanner`, detección de imágenes duplicadas por checksum de
  Active Storage entre vendedores distintos y contexto del vendedor (antigüedad,
  anuncios, ventas, valoración, rechazos y verificación). Acciones: aprobar,
  aprobar y destacar (siete días más la etiqueta `featured`), rechazar con motivo
  predefinido traducido o texto libre, aprobación masiva y atajos j/k/a/r.
- La aprobación/rechazo pasa por `Admin::ListingModeration`, crea una
  notificación y encola `ListingMailer#approved/#rejected` en el idioma del
  vendedor. `Notifier` despacha los correos de anuncios junto a los de pedidos.
- `Admin::ListingQuery` permite ordenar por claves concretas y filtra por estado,
  subárbol de categoría, vendedor, país, precio, etiquetas, destacado, pendiente
  y rango de creación. `Admin::BulkListingAction` permite aprobar, rechazar,
  pausar, archivar, eliminar, añadir/quitar etiqueta, destacar y quitar
  destacado. `Admin::ListingUpdate` valida el JSON de FPS y conserva solo las
  claves de filtros efectivas.
- La gestión de usuarios filtra por rol, estado, confirmación, tienda, rango de
  registro y país; la exportación CSV (`Admin::UserExport`) reutiliza los mismos
  filtros sin la gema `csv` eliminada de Ruby. La suspensión bloquea el acceso
  mediante `User#active_for_authentication?`/`inactive_message` y oculta los
  anuncios con el ámbito de propietario activo. La expulsión también archiva los
  anuncios. Los cambios de rol rechazan el cambio propio y degradar al último
  administrador. La confirmación de correo, el envío de restablecimiento y el
  borrado RGPD quedan auditados.
- La suplantación guarda el id del administrador en
  `session[:impersonator_id]`, inicia sesión como el objetivo y muestra un aviso
  público con acción de parada. Solo los administradores pueden suplantar y
  nunca a otro administrador; inicio y fin quedan auditados.
- La gestión de tiendas verifica/desverifica, alterna el modo vacaciones y edita
  tipo de tienda, datos fiscales/de empresa, políticas y contadores, con enlace
  al propietario.
- Los textos de administración viven en `admin.<locale>.yml` en los seis idiomas;
  los mensajes de cuenta inactiva de Devise se añaden allí
  (`devise.failure.suspended/banned/deleted`).

### Operaciones de administración: pedidos, pagos, disputas, denuncias y reseñas (fase 6B)

- `Admin::OrdersController` lista todos los pedidos con `Admin::OrderQuery`
  (estado, entrega, método de pago, vendedor/tienda, correo del comprador,
  rangos de creación y total, envío tardío y reembolso necesario), ordenación
  permitida, fila de totales (recuento, GMV, comisión) y exportación CSV
  mediante `Admin::OrderExport` (CSV manual porque Ruby 4 eliminó la gema `csv`
  por defecto).
- El detalle del pedido muestra comprador, vendedor/tienda, instantáneas de los
  artículos con enlaces a los anuncios, dirección de envío, referencias de pago
  y reembolso, comisión/neto, la cronología de `OrderEvent`, la `Conversation`
  relacionada, las `OrderNote` internas y el historial de auditoría.
- Recursos RESTful anidados: `payment` (conciliación de transferencias, exige
  referencia y queda auditado), `cancellation` (motivo, restaura stock con
  `Order#cancel!`), `refund` (solo administrador, guarda `refund_reference`),
  `email` (reenvío al comprador/vendedor) y `notes`. `Order#resolve_dispute!`
  acepta un mensaje de resolución opcional y `Order#refund!` acepta una
  referencia.
- `Admin::PaymentsController#index` lista los pedidos pendientes por
  transferencia de más antiguo a más nuevo con el plazo de pago y un formulario
  rápido para marcar pagado. `Admin::BulkPaymentsController#create` delega en
  `Admin::BulkPayment`, que interpreta un número de pedido por línea y muestra
  un resumen de pagados / no encontrados / estado incorrecto.
- `Admin::DisputesController` lista los pedidos en disputa de más antiguo a más
  nuevo con antigüedad y motivo. El detalle combina el resumen del pedido,
  motivo/detalles/fotos de la disputa, mensajes de la conversación en solo
  lectura, cronología, notas internas y el formulario de resolución.
  `Admin::DisputeResolution` llama a `Order#resolve_dispute!`; los reembolsos
  requieren administrador y las liberaciones están disponibles para
  moderadores. `OrderNotifier` envía el mensaje de resolución a ambas partes como
  notificación interna y correo `OrderMailer#dispute_resolved_buyer/#_seller`
  en el idioma correspondiente, respetando las preferencias de correo.
- `Admin::ReportsController` filtra por estado, motivo y tipo denunciado y
  muestra recuentos por estado. `Admin::ReportResolution` resuelve con una acción
  opcional (pausar anuncio, suspender usuario mediante `Admin::UserModeration`,
  despublicar reseña) o desestima, notifica al denunciante mediante `Notifier` y
  escribe una entrada de auditoría. La desestimación masiva pasa por
  `Admin::BulkReportActionsController`.
- `Admin::ReviewsController` filtra valoración, publicación, tienda, presencia
  de respuesta y rango de creación. Despublicar/publicar y la visibilidad de la
  respuesta son acciones de personal; eliminar es solo para administradores.
  Los callbacks de reseña recalculan la valoración de la tienda al despublicar.
  `reviews.seller_reply_visible` oculta la respuesta del vendedor en las vistas
  públicas de tienda, anuncio y pedido, pero la mantiene visible para el
  vendedor.
- Las tarjetas de disputas, denuncias y pagos pendientes del panel enlazan a sus
  pantallas. `Admin::SidebarCounts` cachea disputas abiertas, denuncias abiertas
  y pagos pendientes durante un minuto; el panel reutiliza sus agregados
  cacheados para evitar consultas extra.
- Esquema nuevo: `order_notes` (`order_id`, `author_id`, `body`), `orders
  .refund_reference` y `reviews.seller_reply_visible`.

## Mapa de código

```
app/controllers/application_controller.rb   idioma, metaetiquetas, menú, acceso de personal,
                                            parámetros de búsqueda
app/controllers/concerns/search_rendering.rb render compartido de búsqueda/categoría/tienda
app/controllers/home_controller.rb          portada + vistos recientemente
app/controllers/listings_controller.rb      index/show/new/create/edit/update/destroy,
                                            Turbo Frame de especificaciones, visitas, SEO, caché
app/controllers/listings/                   recursos miembro de envío, pausa y venta
app/controllers/seller/listings_controller.rb  panel del vendedor (pestañas, recuentos, búsqueda)
app/controllers/seller/bulk_listing_actions_controller.rb
app/controllers/seller/base_controller.rb      autenticación, diseño seller, seller_store
app/controllers/seller/dashboard_controller.rb panel KPI
app/controllers/seller/{stores,store_policies,vacations,payouts}_controller.rb
                                            recursos singulares de ajustes de tienda
app/controllers/seller/orders_controller.rb pestañas y detalle de ventas
app/controllers/seller/orders/              envíos, recogidas, pagos,
                                            cancelaciones, albaranes
app/controllers/seller/order_exports_controller.rb exportación CSV de ventas
app/controllers/seller/review_replies_controller.rb respuestas a reseñas
app/controllers/orders/delivery_confirmations_controller.rb
app/controllers/orders/disputes_controller.rb
app/controllers/orders/reviews_controller.rb
app/controllers/notifications_controller.rb   listado, marcar una leída
app/controllers/notifications/read_alls_controller.rb
app/controllers/conversations_controller.rb   pestañas de bandeja, conversación, iniciar chat
app/controllers/conversations/                mensajes, ofertas, lecturas, archivos, leer todo
app/controllers/messages/offer_responses_controller.rb
app/controllers/blocks_controller.rb          bloquear/desbloquear usuarios
app/controllers/account/following_controller.rb
app/services/notifier.rb                    notificación + correo según preferencia
app/services/message_notifier.rb            notificaciones de mensajes/ofertas + correo limitado
app/services/message_safety_scanner.rb      detección de contactos y pagos externos
app/services/conversation_starter.rb        reglas de creación de chat y primer mensaje
app/services/offer_response.rb              aceptar/rechazar/contraoferta + precio reservado
app/mailers/message_mailer.rb               correos de mensajes y ofertas
app/mailers/saved_search_mailer.rb          correos de coincidencia y resumen diario
app/mailers/favourite_mailer.rb             correo de bajada de precio en favoritos
app/jobs/notify_followers_job.rb
app/jobs/saved_search_alert_job.rb
app/jobs/saved_search_digest_job.rb
app/jobs/price_drop_alert_job.rb
app/jobs/expire_offers_job.rb
app/views/conversations/                   lista de bandeja, conversación, compositor, oferta
app/views/messages/_message.html.erb       burbuja, tarjeta de oferta, seguridad y recibos
app/views/messaging/_inbox_badge.html.erb  total de no leídos vivo en cabecera
app/views/account/following/               tiendas seguidas + últimos anuncios
app/services/order_notifier.rb              distribución de eventos de pedido
app/services/profanity_filter.rb            palabras bloqueadas
app/services/seller_order_export.rb         CSV filtrado
app/jobs/auto_deliver_orders_job.rb
app/jobs/auto_complete_orders_job.rb
app/jobs/late_shipment_reminder_job.rb
app/views/seller/orders/                   índice, detalle, albarán
app/views/notifications/                   índice, menú, contador
app/views/layouts/packing_slip.html.erb    diseño imprimible
app/controllers/cart_controller.rb           modelo de lectura de cesta agrupada
app/controllers/cart_items_controller.rb     mutaciones de cesta + Turbo Streams
app/controllers/cart_items/favorites_controller.rb mover fila de cesta a favoritos
app/controllers/checkouts_controller.rb      formulario de pago, PlaceOrder, redirección al proveedor
app/controllers/checkout/confirmations_controller.rb  página de confirmación
app/controllers/orders_controller.rb         historial/detalle de pedidos + token de invitado
app/controllers/orders/cancellations_controller.rb    cancelar pedido impagado
app/controllers/payments/stripe_webhooks_controller.rb webhook firmado de Stripe
app/controllers/account_controller.rb        perfil de cuenta show/update
app/controllers/account/                     contraseña, direcciones, preferencias de
                                            notificación, exportación de datos, eliminación
app/services/seller_dashboard.rb             agregados cacheados del panel
app/services/user_data_export.rb             exportación JSON RGPD
app/validators/spanish_tax_id_validator.rb   validación de NIF/NIE/CIF
app/services/listing_form.rb                escritor del formulario (especificaciones/imágenes/estado)
app/services/bulk_listing_action.rb          pausa/reanudar/eliminar masivo permitido
app/controllers/categories_controller.rb    resolución de rutas de categoría
app/controllers/stores_controller.rb        cabecera, pestañas y reseñas de tienda
app/controllers/{cart,cart_items,favorites,follows,reports,saved_searches}_controller.rb
app/controllers/users/registrations_controller.rb
app/controllers/{conversations,orders,account,pc_finder,pages,legal_pages,sell_offers}_controller.rb
app/controllers/{search_suggestions,seo,newsletter_subscribers}_controller.rb
app/controllers/admin/base_controller.rb        acceso, guardia de personal, layout admin,
                                                ayudantes Pundit y auditoría
app/controllers/admin/dashboard_controller.rb   KPI, gráficos y salud cacheados
app/controllers/admin/moderation_queue_controller.rb
app/controllers/admin/listings_controller.rb    tabla, detalle, edición y borrado
app/controllers/admin/listing_approvals_controller.rb
app/controllers/admin/listing_rejections_controller.rb
app/controllers/admin/bulk_listing_actions_controller.rb
app/controllers/admin/users_controller.rb       directorio, detalle y edición de usuarios
app/controllers/admin/{user_suspensions,user_bans,user_roles}_controller.rb
app/controllers/admin/{user_confirmations,user_password_resets,user_deletions}_controller.rb
app/controllers/admin/{impersonations,user_exports}_controller.rb
app/controllers/admin/stores_controller.rb      tabla, detalle y edición de tiendas
app/controllers/admin/{store_verifications,store_vacations}_controller.rb
app/controllers/admin/{audit_logs,search,placeholders}_controller.rb
app/controllers/admin/orders_controller.rb         tabla, detalle y cronología de pedidos
app/controllers/admin/order_{payments,cancellations,refunds,emails,notes,exports}_controller.rb
                                                   recursos anidados de pedido + CSV
app/controllers/admin/payments_controller.rb       conciliación de transferencias
app/controllers/admin/bulk_payments_controller.rb  resumen de números pegados
app/controllers/admin/disputes_controller.rb       cola y detalle de disputas
app/controllers/admin/dispute_resolutions_controller.rb
app/controllers/admin/reports_controller.rb        cola, detalle y resolución de denuncias
app/controllers/admin/bulk_report_actions_controller.rb
app/controllers/admin/reviews_controller.rb        moderación de reseñas
app/controllers/concerns/admin/auditable.rb     escritor de auditoría de mutaciones
app/policies/admin/                             políticas de personal y administrador
app/services/admin/dashboard.rb                 agregados cacheados del panel
app/services/admin/listing_query.rb             filtros y ordenación permitidos
app/services/admin/listing_moderation.rb        aprobar, rechazar, destacar + correo
app/services/admin/listing_flags.rb             mediana, seguridad y duplicados
app/services/admin/listing_update.rb            escritor del formulario de anuncio
app/services/admin/bulk_listing_action.rb       mutaciones masivas permitidas
app/services/admin/{user_query,user_export,user_moderation}.rb
app/services/admin/{store_query,global_search}.rb
app/services/admin/order_query.rb                relación filtrada y ordenada de pedidos
app/services/admin/{order_export,bulk_payment}.rb
app/services/admin/{dispute_query,dispute_resolution}.rb
app/services/admin/{report_query,report_resolution}.rb
app/services/admin/{review_query,sidebar_counts}.rb
app/models/order_note.rb                         notas internas del personal
app/mailers/listing_mailer.rb                   correos de aprobación/rechazo
app/helpers/admin_helper.rb                     navegación, insignias, gráficos
app/views/layouts/admin.html.erb                barra lateral + barra superior
app/views/admin/shared/                         kit de tabla, filtros, métricas y meta
app/views/admin/{dashboard,moderation_queue,listings,users,stores}/**
app/views/admin/{orders,payments,bulk_payments,disputes,reports,reviews}/**
app/views/admin/{audit_logs,search,placeholders}/
app/javascript/controllers/admin_sidebar_controller.js
app/javascript/controllers/admin_queue_controller.js
app/services/listing_search.rb              búsqueda, facetas, chips, ordenación
app/services/cart_summary.rb                 grupos de cesta, avisos, límite de stock
app/services/checkout/form.rb                validación del pago
app/services/checkout/place_order.rb         creación transaccional de pedidos multiproveedor
app/services/payments/{provider,bank_transfer,cash_on_pickup,stripe,availability}.rb
                                             proveedores y métodos de pago ofrecidos
app/jobs/expire_unpaid_orders_job.rb         barrido de transferencias impagadas
app/mailers/order_mailer.rb                  correos de pedido al comprador/vendedor
app/policies/order_policy.rb                 autorización de pedidos del comprador
app/services/cart_merger.rb                 fusión de cesta invitado -> usuario
app/services/menu_builder.rb                menú gigante cacheado
app/services/home_feed.rb                   consultas de portada
app/services/search_suggestions.rb          sugerencias de anuncios/categorías/tiendas
app/services/newsletter_subscription.rb     estados de suscripción idempotentes
app/services/sitemap_builder.rb             sitemap XML + índice
app/helpers/application_helper.rb           iconos, clases de UI, dinero, JSON-LD, especificaciones
app/views/layouts/application.html.erb      cabecera global, cabecera, main, pie, diálogo de acceso
app/views/shared/                           parciales de diseño, paginación, filtros, avisos
app/views/listings/index.html.erb           página de búsqueda/categoría
app/views/listings/_results.html.erb        resultados en Turbo Frame + barra lateral + hoja
app/views/listings/_filters.html.erb        formulario de filtros compartido escritorio/móvil
app/views/listings/show.html.erb            página de detalle, galería, caja de compra
app/views/listings/_form.html.erb           formulario del vendedor de cinco secciones
app/views/listings/_specs.html.erb          Turbo Frame de especificaciones por categoría
app/views/listings/_actions.html.erb        menú de acciones de fila del vendedor
app/views/seller/listings/index.html.erb    pestañas, tabla/tarjetas, acciones masivas
app/views/seller/dashboard/show.html.erb    KPI, gráfico SVG, acciones, recientes
app/views/seller/{stores,store_policies,vacations,payouts,orders}/
                                             pantallas de ajustes del vendedor
app/views/{cart,checkouts,checkout,orders}/
                                             cesta, pago, confirmación, pedidos del comprador
app/views/order_mailer/                      placed_buyer/placed_seller HTML + texto
app/views/account/                          perfil, contraseña, direcciones,
                                            notificaciones, privacidad/eliminación
app/views/layouts/{seller,account}.html.erb diseños compartidos de área
app/views/stores/show.html.erb              cabecera y pestañas de tienda
app/views/stores/tabs/                      paneles de anuncios/acerca de/reseñas
app/views/favorites/                        parciales de botón/contador de corazón
app/views/devise/                           pantallas de autenticación con estilo
app/views/listings/_card.html.erb           tarjeta de anuncio compartida
app/views/home/index.html.erb               secciones de portada + vistos recientemente
app/assets/tailwind/application.css         tokens de diseño y estilos base
app/assets/images/icons/                    SVG de Lucide incluidos
app/javascript/controllers/                 tema, cajón, menú gigante, autocompletado,
                                            carrusel, desplegable, modal, pestañas, avisos,
                                            consentimiento de cookies, filas con desplazamiento,
                                            volver arriba, filtros, lista de opciones, vista,
                                            favorito, galería, compartir, modal de acceso,
                                            compositor de mensajes
config/routes.rb                            ámbito de idioma + SEO + recursos de fase 2B
config/initializers/warden_hooks.rb         fusión de cesta de invitado al acceder
config/initializers/content_security_policy.rb
config/initializers/security_headers.rb
config/locales/                             textos de UI en seis idiomas (+ archivos por dominio)
db/seeds.rb                                 cargador
db/seeds/*.rb                               taxonomía y datos de referencia
script/search_explain.rb                    EXPLAIN ANALYZE con 5k anuncios
test/integration/                           portada, SEO, búsqueda, acceso, rendimiento
test/services/listing_search_test.rb
test/services/cart_summary_test.rb
test/services/checkout/place_order_test.rb
test/services/payments/availability_test.rb
test/jobs/expire_unpaid_orders_job_test.rb
test/mailers/order_mailer_test.rb
test/integration/{checkout,orders,stripe_webhook}_test.rb
test/system/checkout_flow_test.rb
test/system/                                adaptable + modal de acceso
test/i18n/locale_parity_test.rb
test/integration/admin_{access,panel,moderation,users}_test.rb
test/integration/admin_{orders,disputes,reports,reviews}_test.rb
test/services/admin/sidebar_counts_test.rb
test/system/admin_moderation_flow_test.rb
test/seeds_test.rb
```

## Pendientes para fases posteriores

- Las pantallas de administración de categorías, filtros, páginas legales,
  juegos, boletín y ajustes son marcadores hasta la fase 6C.
- Los reembolsos se registran manualmente con una referencia; todavía no se llama
  a la API de reembolsos del proveedor de pago.
- No hay autenticación en dos pasos para administración; Devise lockable ya
  limita los inicios de sesión fallidos. Decidir si el 2FA de personal es
  obligatorio antes de la fase 6C.
- La suplantación se basa en sesión y queda auditada; no tiene caducidad
  automática.
- El panel y las señales de moderación son heurísticos (mediana de precio y
  reutilización de checksum de imagen), no detección de fraude.
- El rendimiento del panel del vendedor se cachea cinco minutos; los eventos de
  pedido no lo invalidan de inmediato.
- Los correos de ciclo de vida a administración dependen de
  `Setting.support_email`; aún no hay bandeja de personal.
- Pagos en línea (Stripe Connect) e historial de pagos al vendedor pendientes.
- Los códigos de descuento aparecen en la navegación del vendedor como elemento
  desactivado.
- Las pestañas de tienda renderizan el panel activo en línea para SEO y cargan
  las demás mediante Turbo Frame; se pueden añadir marcadores
  `loading="lazy"` si los paneles crecen.
- "Cargar más" en móvil navega a la página siguiente dentro del frame de
  resultados en lugar de añadir; la adición infinita real puede añadirse con un
  endpoint de stream.
- El acceso con Google solo se muestra cuando `GOOGLE_CLIENT_ID` y
  `GOOGLE_CLIENT_SECRET` están configurados.
- URL reales de perfiles sociales y textos legales por idioma.
- Endpoints de API (ListingSearch ya está preparado para API).
- Sin indicador de escritura en las conversaciones (fuera de alcance de forma
  explícita).
- La detección de seguridad de mensajes es heurística; la revisión de moderación
  sigue siendo manual.

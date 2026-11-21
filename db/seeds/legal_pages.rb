legal_pages = [
  {
    slug: "terms",
    title: "Términos y condiciones",
    body: <<~HTML
      <p>PCMarket es un mercado de tecnología nueva y de segunda mano. Los vendedores son responsables de la exactitud de sus anuncios y de cumplir la legislación aplicable.</p>
      <p>El uso de la plataforma implica la aceptación de estas condiciones.</p>
    HTML
  },
  {
    slug: "privacy",
    title: "Política de privacidad",
    body: <<~HTML
      <p>Tratamos tus datos personales de acuerdo con el Reglamento General de Protección de Datos (RGPD) y la normativa española aplicable.</p>
      <p>Puedes ejercer tus derechos de acceso, rectificación, supresión y portabilidad escribiendo a nuestro equipo de privacidad.</p>
    HTML
  },
  {
    slug: "cookies",
    title: "Política de cookies",
    body: <<~HTML
      <p>Usamos cookies necesarias para el funcionamiento del sitio y, con tu consentimiento, cookies analíticas y de marketing.</p>
      <p>Puedes cambiar tus preferencias en cualquier momento desde el enlace «Preferencias de cookies» del pie de página.</p>
    HTML
  },
  {
    slug: "legal_notice",
    title: "Aviso legal",
    body: <<~HTML
      <p>Este sitio es operado por PCMarket. La información publicada por los vendedores es responsabilidad de cada vendedor.</p>
    HTML
  }
].freeze

legal_pages.each do |attributes|
  page = LegalPage.find_or_initialize_by(
    slug: attributes[:slug], country_code: "ES", locale: "es"
  )
  page.assign_attributes(
    title: attributes[:title],
    body: attributes[:body],
    version: 1,
    published: true
  )
  page.save!
end

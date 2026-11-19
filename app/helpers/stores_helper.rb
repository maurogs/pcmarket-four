module StoresHelper
  # Five stars with the first `rating` filled — reviews tab summary and cards.
  def review_stars(rating, size: "h-4 w-4")
    stars = (1..5).map do |star|
      filled = star <= rating.to_f.round
      tag.span(icon("star", class: size, fill: filled ? "currentColor" : "none"),
               class: filled ? "text-amber-500" : "text-line-strong")
    end
    tag.span(safe_join(stars), class: "inline-flex items-center gap-0.5",
             role: "img", aria: { label: t("stores.review.stars", rating: rating) })
  end
end

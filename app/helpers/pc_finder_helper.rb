module PcFinderHelper
  def fit_tone(fit)
    case fit.to_s
    when "great" then :success
    when "good" then :brand
    else :accent
    end
  end
end

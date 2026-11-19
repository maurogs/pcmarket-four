# Computes a listing's performance score from its GPU (and CPU) spec values,
# using the per-FilterOption `performance_score` benchmarks. The CPU pulls
# its weight out of the GPU score; without a scored GPU there is no score.
module Listings
  class PerformanceScorer
    CPU_WEIGHT = 0.3

    def self.call(listing)
      new(listing).call
    end

    def initialize(listing)
      @listing = listing
    end

    def call
      gpu = benchmark_for("gpu_model")
      return if gpu.nil?

      cpu = benchmark_for("cpu_model")
      return gpu if cpu.nil?

      (gpu * (1 - CPU_WEIGHT) + cpu * CPU_WEIGHT).round
    end

    private

    # Specs store arrays of machine values; the first scored option of the
    # filter wins. nil when the filter or a scored value does not exist.
    def benchmark_for(key)
      values = Array(@listing.specs&.dig(key)).map(&:to_s).reject(&:blank?)
      return if values.empty?

      FilterOption
        .where(filter_definition: FilterDefinition.where(key: key))
        .where(value: values)
        .where.not(performance_score: nil)
        .order(:position, :id)
        .pick(:performance_score)
    end
  end
end

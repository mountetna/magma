class Magma::Metric
  def initialize record
    @record = record
    @score = :failure
    @details = []
  end

  class << self
    def category category=:default
      @category ||= category
    end

    def metric_name
      name.split(/::/).last.snake_case.to_sym
    end
  end

  def category
    self.class.category
  end

  def metric_name
    self.class.metric_name
  end

  def to_hash
    {
      name: metric_name,
      score: metric_score,
      category: category,
      message: @message,
      details: @details
    }
  end

  def detail title, entries
    @details.push title: title, entries: entries
  end

  def metric_score
    test
    @score
  end

  def success message = "Test passed"
    @score = :success
    @message = message
  end

  def failure message = "Test failed"
    @score = :failure
    @message = message
  end

  def invalid message = "Test is invalid"
    @score = :invalid
    @message = message
  end

  def test
    nil
  end
end

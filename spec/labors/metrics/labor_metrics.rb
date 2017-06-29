class Labor < Magma::Model
  class Lucrative < Magma::Metric
    def test
      labor = Labor[name: @record.name]
      detail(:lucrative, ["Checked worth"])
      return success if labor.prize.any?{ |p| p.worth > 2 }
      failure
    end
  end
end

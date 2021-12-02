describe Magma::QuestionFormat do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  context "leaves" do
    it "works for question formats" do
      simple_format = [
        "labors::project#name",
        [
          ["labors::labor#name",
           ["labors::victim#name", "labors::victim#name"]],
          ["labors::labor#name",
           ["labors::victim#name", "labors::victim#weapon"]],
        ],
      ]

      result = Magma::QuestionFormat.new("labors", simple_format).leaves

      expect(result).to eq([
        "labors::project#name",
        "labors::victim#name",
        "labors::victim#weapon",
      ])
    end

    it "works for formats with many branches" do
      branched_format = [
        "labors::monster#name",
        ["labors::labor#number",
         "labors::victim#name",
         ["labors::victim#name",
          ["labors::wound#id", "labors::wound#location"]]],
      ]

      result = Magma::QuestionFormat.new("labors", branched_format).leaves

      expect(result).to eq([
        "labors::monster#name",
        "labors::labor#number",
        "labors::victim#name",
        "labors::wound#location",
      ])
    end

    it "works for matrix attribute format" do
      matrix_format = [
        "labors::project#name",
        [
          "labors::labor#name",
          [
            "labors::labor#contributions",
            ["Athens", "Sparta"],
          ],
        ],
      ]

      result = Magma::QuestionFormat.new("labors", matrix_format).leaves

      expect(result).to eq([
        "labors::project#name",
        "labors::labor#name",
        "labors::labor#contributions",
      ])
    end
  end
end

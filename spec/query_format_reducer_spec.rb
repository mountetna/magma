describe Magma::QueryFormatReducer do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    @reducer = Magma::QueryFormatReducer.new("labors")
  end

  context "reduce_leaves" do
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

      result = @reducer.reduce_leaves(data_source: simple_format)

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

      result = @reducer.reduce_leaves(data_source: branched_format)

      expect(result).to eq([
        "labors::monster#name",
        "labors::labor#number",
        "labors::victim#name",
        "labors::wound#location",
      ])
    end

    # it "works for nested question answers" do
    #   nested_answer = [
    #     [
    #       "The Twelve Labors of Hercules",
    #       [
    #         [
    #           [
    #             "labor1",
    #             [
    #               ["Jane Doe", "Jane Doe"],
    #               ["John Doe", "John Doe"],
    #             ],
    #           ],
    #           [
    #             "labor2",
    #             [
    #               ["Shawn Doe", "Shawn Doe"],
    #               ["Susan Doe", "Susan Doe"],
    #             ],
    #           ],
    #           ["labor3",
    #            []],
    #         ],
    #         [
    #           [
    #             "labor1",
    #             [
    #               ["Jane Doe", "sling"],
    #               ["John Doe", "sword"],
    #             ],
    #           ],
    #           [
    #             "labor2",
    #             [
    #               ["Shawn Doe", "hands"],
    #               ["Susan Doe", "crossbow"],
    #             ],
    #           ],
    #           [
    #             "labor3",
    #             [],
    #           ],
    #         ],
    #       ],
    #     ],
    #   ]
    #   require "pry"
    #   binding.pry
    #   result = @reducer.reduce_leaves(data_source: nested_answer)

    #   expect(result).to eq([
    #     [
    #       "The Twelve Labors of Hercules",
    #       [
    #         "Jane Doe", "John Doe", "Shawn Doe", "Susan Doe",
    #       ],
    #       [
    #         "sling", "sword", "hands", "crossbow",
    #       ],
    #     ],
    #   ])
    # end

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

      result = @reducer.reduce_leaves(data_source: matrix_format, expand_matrices: false)

      expect(result).to eq([
        "labors::project#name",
        "labors::labor#name",
        "labors::labor#contributions",
      ])

      result = @reducer.reduce_leaves(data_source: matrix_format, expand_matrices: true)

      expect(result).to eq([
        "labors::project#name",
        "labors::labor#name",
        "labors::labor#contributions.Athens",
        "labors::labor#contributions.Sparta",
      ])
    end

    # it "works for matrix answers" do
    #   matrix_answer = [
    #     [
    #       "The Twelve Labors of Hercules",
    #       ["Augean Stables", [10, 11]],
    #       ["Lernean Hydra", [20, 21]],
    #       ["Nemean Lion", [30, 31]],
    #     ],
    #   ]

    #   result = @reducer.reduce_leaves(matrix_answer, 1, expand_matrices: false)

    #   expect(result).to eq([
    #     [
    #       "The Twelve Labors of Hercules",
    #       [
    #         [10, 11],
    #         [20, 21],
    #         [30, 31],
    #       ],
    #     ],
    #   ])

    #   @reducer = Magma::QueryFormatReducer.new(project_name: "labors", expand_matrices: true)
    #   result = @reducer.reduce_leaves(matrix_answer, 1)

    #   expect(result).to eq([
    #     [
    #       "The Twelve Labors of Hercules",
    #       [10, 20, 30],
    #       [11, 21, 31],
    #     ],
    #   ])
    # end
  end
end

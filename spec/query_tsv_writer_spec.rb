require "rspec"

describe Magma::QueryTSVWriter do
  it "should write a tsv with all attributes and records from multiple models" do
    project = create(:project, name: "The Twelve Labors of Hercules")
    labors = create_list(:labor, 2, project: project)

    lion_labor = labors.first
    hydra_labor = labors.last

    lion_monster = create(:monster, :lion, labor: lion_labor)
    hydra_monster = create(:monster, :hydra, labor: hydra_labor)

    john_doe = create(:victim, name: "John Doe", monster: lion_monster, country: "Italy")
    jane_doe = create(:victim, name: "Jane Doe", monster: lion_monster, country: "Greece")

    susan_doe = create(:victim, name: "Susan Doe", monster: hydra_monster, country: "Italy")
    shawn_doe = create(:victim, name: "Shawn Doe", monster: hydra_monster, country: "Greece")

    create(:wound, victim: john_doe, location: "Arm", severity: 5)
    create(:wound, victim: john_doe, location: "Leg", severity: 1)
    create(:wound, victim: jane_doe, location: "Arm", severity: 2)
    create(:wound, victim: jane_doe, location: "Head", severity: 4)
    create(:wound, victim: susan_doe, location: "Arm", severity: 3)
    create(:wound, victim: susan_doe, location: "Leg", severity: 3)
    create(:wound, victim: shawn_doe, location: "Arm", severity: 1)
    create(:wound, victim: shawn_doe, location: "Leg", severity: 1)

    question = Magma::Question.new(
      "labors",
      ["monster", "::all",
       [
        ["labor", "number"],
        ["victim", "::first", "name"],
        ["victim", "::all", "wound", "::all", "location"],
      ]]
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question).write_tsv { |lines| file.write lines }

    tsv = CSV.parse(file.string, col_sep: "\t")
    header = tsv[0]
    expect(header).to eq(["labors::monster#name", "labors::labor#number", "labors::victim#name", "labors::wound#location"])
    expect(tsv.size).to eq(3)

    hydra_record = tsv[1]
    lion_record = tsv[2]
    john_doe.refresh
    jane_doe.refresh
    shawn_doe.refresh
    susan_doe.refresh

    expect(hydra_record.first).to eq(hydra_monster.name)
    expect(hydra_record[1].to_i).to eq(hydra_labor.number)
    expect([susan_doe.name, shawn_doe.name].include?(hydra_record[2])).to eq(true)
    expect(JSON.parse(hydra_record.last)).to match_array(shawn_doe.wound.map(&:location).concat(susan_doe.wound.map(&:location)))

    expect(lion_record.first).to eq(lion_monster.name)
    expect(lion_record[1].to_i).to eq(lion_labor.number)
    expect([john_doe.name, jane_doe.name].include?(lion_record[2])).to eq(true)
    expect(JSON.parse(lion_record.last)).to match_array(john_doe.wound.map(&:location).concat(jane_doe.wound.map(&:location)))
  end

  it "can handle multiple table columns, filtered out differently" do
    project = create(:project, name: "The Twelve Labors of Hercules")
    labors = create_list(:labor, 2, project: project)

    lion_labor = labors.first
    hydra_labor = labors.last

    lion_monster = create(:monster, :lion, labor: lion_labor)
    hydra_monster = create(:monster, :hydra, labor: hydra_labor)

    john_doe = create(:victim, name: "John Doe", monster: lion_monster, country: "Italy")
    jane_doe = create(:victim, name: "Jane Doe", monster: lion_monster, country: "Greece")

    susan_doe = create(:victim, name: "Susan Doe", monster: hydra_monster, country: "Italy")
    shawn_doe = create(:victim, name: "Shawn Doe", monster: hydra_monster, country: "Greece")

    create(:wound, victim: john_doe, location: "Arm", severity: 5)
    create(:wound, victim: john_doe, location: "Leg", severity: 1)
    create(:wound, victim: jane_doe, location: "Arm", severity: 2)
    create(:wound, victim: jane_doe, location: "Head", severity: 4)
    create(:wound, victim: susan_doe, location: "Arm", severity: 3)
    create(:wound, victim: susan_doe, location: "Leg", severity: 3)
    create(:wound, victim: shawn_doe, location: "Arm", severity: 1)
    create(:wound, victim: shawn_doe, location: "Leg", severity: 1)

    question = Magma::Question.new(
      "labors",
      ["victim", "::all",
       [
        ["wound", ["location", "::equals", "Head"], "::all", "severity"],
        ["wound", ["location", "::equals", "Arm"], "::all", "severity"],
      ]]
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header).to eq("labors::victim#name\tlabors::wound#severity\tlabors::wound#severity")
    expect(lines.size).to eq(5)

    expect(lines[1].split("\t")).to eq([
      "Jane Doe",
      "[4]",
      "[2]",
    ])

    expect(lines[2].split("\t")).to eq([
      "John Doe",
      "",
      "[5]",
    ])

    expect(lines[3].split("\t")).to eq([
      "Shawn Doe",
      "",
      "[1]",
    ])

    expect(lines[4].split("\t")).to eq([
      "Susan Doe",
      "",
      "[3]",
    ])
  end

  it "can transpose the resulting data" do
    project = create(:project, name: "The Twelve Labors of Hercules")
    labors = create_list(:labor, 2, project: project)

    lion_labor = labors.first
    hydra_labor = labors.last

    lion_monster = create(:monster, :lion, labor: lion_labor)
    hydra_monster = create(:monster, :hydra, labor: hydra_labor)

    john_doe = create(:victim, name: "John Doe", monster: lion_monster, country: "Italy")
    jane_doe = create(:victim, name: "Jane Doe", monster: lion_monster, country: "Greece")

    susan_doe = create(:victim, name: "Susan Doe", monster: hydra_monster, country: "Italy")
    shawn_doe = create(:victim, name: "Shawn Doe", monster: hydra_monster, country: "Greece")

    create(:wound, victim: john_doe, location: "Arm", severity: 5)
    create(:wound, victim: john_doe, location: "Leg", severity: 1)
    create(:wound, victim: jane_doe, location: "Arm", severity: 2)
    create(:wound, victim: jane_doe, location: "Head", severity: 4)
    create(:wound, victim: susan_doe, location: "Arm", severity: 3)
    create(:wound, victim: susan_doe, location: "Leg", severity: 3)
    create(:wound, victim: shawn_doe, location: "Arm", severity: 1)
    create(:wound, victim: shawn_doe, location: "Leg", severity: 1)

    question = Magma::Question.new(
      "labors",
      ["monster", "::all",
       [
        ["labor", "number"],
        ["victim", "::first", "name"],
        ["victim", "::all", "wound", "::all", "location"],
      ]]
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question, transpose: true).write_tsv { |lines| file.write lines }

    tsv = CSV.parse(file.string, col_sep: "\t")
    header = tsv.map { |l| l.first }

    expect(tsv.length).to eq(4)

    john_doe.refresh
    jane_doe.refresh
    shawn_doe.refresh
    susan_doe.refresh

    expect(tsv.first[1..-1]).to match_array([hydra_monster.name, lion_monster.name])

    expect(JSON.parse(tsv.last[1])).to match_array(shawn_doe.wound.map(&:location).concat(susan_doe.wound.map(&:location)))
    expect(JSON.parse(tsv.last[2])).to match_array(john_doe.wound.map(&:location).concat(jane_doe.wound.map(&:location)))
  end

  it "should contain expanded matrix header if expand_matrices" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question, expand_matrices: true).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]

    expect(header).to eq("labors::labor#name\tlabors::labor#number\tlabors::labor#contributions.Athens\tlabors::labor#contributions.Sparta")
    expect(lines.size).to eq(4)

    expect(lines[1].split("\t")).to eq([
      belt.name,
      belt.number.to_s,
      "10",
      "11",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "20",
      "21",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "30",
      "31",
    ])
  end

  it "can handle multiple matrix columns, when expanding" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question, expand_matrices: true).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]

    expect(header).to eq("labors::labor#name\tlabors::labor#number\tlabors::labor#contributions.Athens\tlabors::labor#contributions.Sparta\tlabors::labor#contributions.Thebes")
    expect(lines.size).to eq(4)

    expect(lines[1].split("\t")).to eq([
      belt.name,
      belt.number.to_s,
      "10",
      "11",
      "13",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "20",
      "21",
      "23",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "30",
      "31",
      "33",
    ])
  end

  it "should not contain expanded matrix header if not expand_matrices" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header).to eq("labors::labor#name\tlabors::labor#number\tlabors::labor#contributions")
    expect(lines.size).to eq(4)

    expect(lines[1].split("\t")).to eq([
      belt.name,
      belt.number.to_s,
      "[10, 11]",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "[20, 21]",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "[30, 31]",
    ])
  end

  it "can handle multiple matrix columns, when not expanding" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]

    expect(header).to eq("labors::labor#name\tlabors::labor#number\tlabors::labor#contributions\tlabors::labor#contributions")
    expect(lines.size).to eq(4)

    expect(lines[1].split("\t")).to eq([
      belt.name,
      belt.number.to_s,
      "[10, 11]",
      "[13]",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "[20, 21]",
      "[23]",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "[30, 31]",
      "[33]",
    ])
  end

  it "can tranpose unexpanded matrix column" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question, transpose: true).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines.map { |l| l.split("\t").first }

    expect(lines.length).to eq(4)

    expect(lines.first.split("\t")[1..-1]).to match_array([belt.name, cattle.name, apples.name])
    expect(lines[2].split("\t")[1..-1]).to match_array(["[10, 11]", "[20, 21]", "[30, 31]"])
    expect(lines.last.split("\t")[1..-1]).to match_array(["[13]", "[23]", "[33]"])
  end

  it "can transpose expanded matrix columns" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(question, transpose: true, expand_matrices: true).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines.map { |l| l.split("\t").first }

    expect(lines.length).to eq(5)

    expect(lines.first.split("\t")[1..-1]).to match_array([belt.name, cattle.name, apples.name])
    expect(lines[2].split("\t")[1..-1]).to match_array(["10", "20", "30"])
    expect(lines[3].split("\t")[1..-1]).to match_array(["11", "21", "31"])
    expect(lines.last.split("\t")[1..-1]).to match_array(["13", "23", "33"])
  end

  it "throws exception if user_columns is wrong size" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    expect {
      Magma::QueryTSVWriter.new(question, user_columns: ["whoami"], expand_matrices: true).write_tsv { |lines| file.write lines }
    }.to raise_error(Magma::TSVError)
  end

  it "can provide display labels to rename columns, expanded matrix" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(
      question,
      user_columns: ["labor", "number", "first_contribution", "second_contribution"],
      expand_matrices: true,
    ).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]

    expect(header).to eq("labor\tnumber\tfirst_contribution.Athens\tfirst_contribution.Sparta\tsecond_contribution.Thebes")
    expect(lines.size).to eq(4)

    expect(lines[1].split("\t")).to eq([
      belt.name,
      belt.number.to_s,
      "10",
      "11",
      "13",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "20",
      "21",
      "23",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "30",
      "31",
      "33",
    ])
  end

  it "can provide display labels to rename columns, unexpanded matrix" do
    project = create(:project, name: "The Twelve Labors of Hercules")

    matrix = [
      [10, 11, 12, 13],
      [20, 21, 22, 23],
      [30, 31, 32, 33],
    ]

    belt = create(:labor, name: "Belt of Hippolyta", number: 9, contributions: matrix[0], project: project)
    cattle = create(:labor, name: "Cattle of Geryon", number: 10, contributions: matrix[1], project: project)
    apples = create(:labor, name: "Golden Apples of the Hesperides", number: 11, contributions: matrix[2], project: project)

    question = Magma::Question.new(
      "labors",
      ["labor", "::all",
       [
        "number",
        ["contributions", "::slice", ["Athens", "Sparta"]],
        ["contributions", "::slice", ["Thebes"]],
      ]],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(
      question,
      user_columns: ["labor", "number", "first_contribution", "second_contribution"],
    ).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]

    expect(header).to eq("labor\tnumber\tfirst_contribution\tsecond_contribution")
    expect(lines.size).to eq(4)

    expect(lines[1].split("\t")).to eq([
      belt.name,
      belt.number.to_s,
      "[10, 11]",
      "[13]",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "[20, 21]",
      "[23]",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "[30, 31]",
      "[33]",
    ])
  end
end

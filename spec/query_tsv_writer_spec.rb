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

    lines = file.string.split("\n")
    header = lines[0]
    expect(header).to eq("labors::monster#name\tlabors::labor#number\tlabors::victim#name\tlabors::wound#location")
    expect(lines.size).to eq(3)

    hydra_record = lines[1].split("\t")
    lion_record = lines[2].split("\t")
    john_doe.refresh
    jane_doe.refresh
    shawn_doe.refresh
    susan_doe.refresh

    expect(hydra_record.first).to eq(hydra_monster.name)
    expect(hydra_record[1].to_i).to eq(hydra_labor.number)
    expect([susan_doe.name, shawn_doe.name].include?(hydra_record[2])).to eq(true)
    expect(hydra_record.last.split(",")).to match_array(shawn_doe.wound.map(&:location).concat(susan_doe.wound.map(&:location)))

    expect(lion_record.first).to eq(lion_monster.name)
    expect(lion_record[1].to_i).to eq(lion_labor.number)
    expect([john_doe.name, jane_doe.name].include?(lion_record[2])).to eq(true)
    expect(lion_record.last.split(",")).to match_array(john_doe.wound.map(&:location).concat(jane_doe.wound.map(&:location)))
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
      "4",
      "2",
    ])

    expect(lines[2].split("\t")).to eq([
      "John Doe",
      "",
      "5",
    ])

    expect(lines[3].split("\t")).to eq([
      "Shawn Doe",
      "",
      "1",
    ])

    expect(lines[4].split("\t")).to eq([
      "Susan Doe",
      "",
      "3",
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

    lines = file.string.split("\n")
    header = lines.map { |l| l.split("\t").first }

    expect(lines.length).to eq(4)

    john_doe.refresh
    jane_doe.refresh
    shawn_doe.refresh
    susan_doe.refresh

    expect(lines.first.split("\t")[1]).to eq(hydra_monster.name)
    expect(lines.first.split("\t")[2]).to eq(lion_monster.name)

    expect(lines.last.split("\t")[1].split(",")).to match_array(shawn_doe.wound.map(&:location).concat(susan_doe.wound.map(&:location)))
    expect(lines.last.split("\t")[2].split(",")).to match_array(john_doe.wound.map(&:location).concat(jane_doe.wound.map(&:location)))
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
      "10,11",
    ])

    expect(lines[2].split("\t")).to eq([
      cattle.name,
      cattle.number.to_s,
      "20,21",
    ])

    expect(lines[3].split("\t")).to eq([
      apples.name,
      apples.number.to_s,
      "30,31",
    ])
  end

  it "can tranpose unexpanded matrix column" do
    project = create(:project, name: "The Twelve Labors of Hercules")
    labors = create_list(:labor, 4, project: project)

    payload = Magma::Payload.new
    model = Magma.instance.get_model("labors", "labor")
    retrieval = Magma::Retrieval.new(
      model,
      nil,
      [:contributions],
      filter: nil,
      page: 1,
      page_size: 5,
      output_predicates: [Magma::Retrieval::StringOutputPredicate.new("contributions[]Sidon")],
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(
      model,
      retrieval,
      payload,
      expand_matrices: true,
    ).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header.include?("contributions.Sidon")).to eq(true)
    expect(header.include?("contributions.Athens")).to eq(false)
    expect(header.include?("contributions\n")).to eq(false)
    expect(lines[1].count("\t")).to eq(1)
  end

  it "can transpose expanded matrix columns" do
    project = create(:project, name: "The Twelve Labors of Hercules")
    labor = create(:labor, project: project)
    prizes = create_list(:prize, 3, labor: labor)

    payload = Magma::Payload.new
    model = Magma.instance.get_model("labors", "prize")
    retrieval = Magma::Retrieval.new(
      model,
      nil,
      "all",
      filter: nil,
      page: 1,
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(model, retrieval, payload).write_tsv { |lines| file.write lines }
    lines = file.string.split("\n")
    header = lines[0]

    expect(header.split("\t").sort).to eql(["labor", "name", "worth"])
    expect(lines[1].count("\t")).to eq(2)
  end

  it "can provide display labels to rename columns" do
  end
end

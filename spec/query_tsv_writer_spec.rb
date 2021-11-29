require "rspec"

describe Magma::QueryTSVWriter do
  it "should write a tsv with all attributes and records from multiple models" do
    project = create(:project, name: "The Twelve Labors of Hercules")
    labors = create_list(:labor, 4, project: project)

    lion_monster = create(:monster, :lion, labor: @lion)
    hydra_monster = create(:monster, :hydra, labor: @hydra)

    john_doe = create(:victim, name: "John Doe", monster: lion_monster, country: "Italy")
    jane_doe = create(:victim, name: "Jane Doe", monster: lion_monster, country: "Greece")

    susan_doe = create(:victim, name: "Susan Doe", monster: hydra_monster, country: "Italy")
    shawn_doe = create(:victim, name: "Shawn Doe", monster: hydra_monster, country: "Greece")

    create(:wound, victim: john_doe, location: "Arm", severity: 5)
    create(:wound, victim: john_doe, location: "Leg", severity: 1)
    create(:wound, victim: jane_doe, location: "Arm", severity: 2)
    create(:wound, victim: jane_doe, location: "Leg", severity: 4)
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

    require "pry"
    binding.pry

    file = StringIO.new
    Magma::QueryTSVWriter.new(question).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header).to eq("labors::monster#name\tlabors::labor#number\tlabors::victim#name\tlabors::wound#location")
    expect(lines.size).to eq(5)

    name_index = header.split("\t").find_index("name")
    tsv_labors_names = lines.drop(1).map { |l| l.split("\t")[name_index] }.sort
    labors_names = labors.map(&:name).sort
    expect(tsv_labors_names).to eq(labors_names)
  end

  it "can transpose the resulting data" do
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
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(
      model,
      retrieval,
      payload,
      expand_matrices: true,
      transpose: true,
    ).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines.map { |l| l.split("\t").first }

    expect(lines.length).to eq(5)
    model.attributes[:contributions].validation_object.options.each do |opt|
      expect(header.include?("contributions.#{opt}")).to eq(true)
    end

    labors_names = labors.map(&:name).sort
    expect(lines.first).to eq(["name"].concat(labors_names).join("\t"))
  end

  it "should contain expanded matrix header if expand_matrices" do
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
    model.attributes[:contributions].validation_object.options.each do |opt|
      expect(header.include?("contributions.#{opt}")).to eq(true)
    end
    expect(lines[1].count("\t")).to eq(4)
  end

  it "should not contain expanded matrix header if not expand_matrices" do
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
    )

    file = StringIO.new
    Magma::QueryTSVWriter.new(model, retrieval, payload).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    model.attributes[:contributions].validation_object.options.each do |opt|
      expect(header.include?("contributions.#{opt}")).to eq(false)
    end
    expect(header.include?("contributions")).to eq(true)
    expect(lines[1].count("\t")).to eq(1)
  end

  it "should contain expanded matrix headers with output_predicate if expand_matrices" do
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

  it "should not contain the identifier for table models" do
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

  it "should contain only matrix attribute name even with output_predicate if not expand_matrices" do
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
    Magma::QueryTSVWriter.new(model, retrieval, payload).write_tsv { |lines| file.write lines }

    lines = file.string.split("\n")
    header = lines[0]
    expect(header.include?("contributions.Sidon")).to eq(false)
    expect(header.include?("contributions")).to eq(true)
    expect(lines[1].count("\t")).to eq(1)
  end

  it "can provide display labels to rename columns" do
  end
end

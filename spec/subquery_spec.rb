describe Magma::Subquery do
  let(:project_name) { "labors" }
  let(:query) { ["labor", ["prize", ["::has", "worth"], "::every"], "::all", "identifier"] }
  let(:question) {
    Magma::Question.new(project_name, query)
  }
  let(:model) do
    Magma.instance.get_model(project_name, "prize")
  end
  let(:alias_name) do
    "derived_table_name_alias"
  end
  let(:filter) do
    Magma::FilterPredicate.new(question, model, alias_name, query[1])
  end

  let(:parent_attribute) do
    model.attributes.values.select do |attr|
      attr.is_a?(Magma::ParentAttribute)
    end.first
  end

  it "correctly aliases the subquery derived table" do
    subquery = Magma::Subquery.new(
      model,
      alias_name,
      model.identity.column_name,
      parent_attribute.column_name,
      filter,
      "::every"
    )

    main_query = model.from(
      Sequel.as(model.table_name, "test_alias")
    )

    expect(main_query.sql.include?("as #{alias_name}")).to eq(false)

    main_query = subquery.apply(main_query)

    expect(main_query.sql.include?("as #{alias_name}")).to eq(true)
  end

  it "includes a group by clause" do
  end

  it "includes the right having condition for ::every" do
  end

  it "includes the right having condition for ::any" do
  end
end

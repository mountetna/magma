require 'rspec'
require 'sequel'

describe 'QueryExecutor' do

  mock_db = Sequel.connect('mock://DB')

  it 'should raise an error when a timeout is provided and the database is not postgres' do
    expect { Magma::QueryExecutor.new(Sequel.mock, 10, mock_db) }.to raise_error(ArgumentError)
  end

  it 'should use a statement_timeout when provided a timeout' do
    allow(mock_db).to receive(:adapter_scheme) { :postgres }
    query = 'SELECT * FROM mocks'
    Magma::QueryExecutor.new(mock_db[query], 10, mock_db).execute

    expected = "
      BEGIN
      SET LOCAL statement_timeout = 10
      #{query}
      COMMIT
    ".strip.split("\n").map(&:strip)

    expect(mock_db.sqls).to eq(expected)
  end

  it 'should not use a statement_timeout when a timeout is not set' do
    allow(mock_db).to receive(:adapter_scheme) { :postgres }
    query = 'SELECT * FROM mocks'
    Magma::QueryExecutor.new(mock_db[query], nil, mock_db).execute
    expect(mock_db.sqls.first).to eq(query)
  end

  it 'should raise an error when the query execution surpasses the timeout' do
    db = Magma.instance.db
    query = db['fake query that takes a long time']
    allow(query).to receive(:sql) { 'SELECT pg_sleep(1);' }

    expect { Magma::QueryExecutor.new(query, 900, db).execute }.to raise_error(Sequel::DatabaseError)
  end

  it 'should fetch rows' do
    project = create(:project, name: 'The Twelve Labors of Hercules')
    labors = create_list(:labor, 4, project: project)
    names = labors.map(&:name).sort

    db = Magma.instance.db
    query = db['SELECT * FROM labors.labors']

    results = Magma::QueryExecutor.new(query, nil, db).execute.map{ |row| row[:name] }.sort
    expect(results).to eq(names)

    results = Magma::QueryExecutor.new(query, 1000, db).execute.map{ |row| row[:name] }.sort
    expect(results).to eq(names)
  end
end
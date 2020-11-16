require_relative '../lib/magma'

describe Magma::Censor do
  def to_record_set(model, revisions)
    loader = double('loader')
    allow(loader).to receive(:identifier_id) { nil }
    revisions.map do |record_name, revision|
      # The RecordEntry should require a Loader, but the censor doesn't need it
      entry = Magma::RecordEntry.new(model, record_name, loader)

      entry << revision
      [
        record_name,
        entry
      ]
    end.to_h
  end

  it 'nothing censored for authorized users with unrestricted permissions' do
    victim = create(:victim, name: 'Apollodorus', country: 'Greece')
    model = Magma.instance.magma_projects[:labors].models[:victim]
    user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        first: 'Zeus',
        perm: 'A:labors'
    )
    censor = Magma::Censor.new(
        user,
        'labors'
    )
    revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { country: 'Rome' }})
    expect(censor.censored_reasons(model, revisions)).to be_empty
  end

  it 'revisions censored for users with restricted permissions' do
    victim = create(:victim, name: 'Apollodorus', country: 'Greece')
    model = Magma.instance.magma_projects[:labors].models[:victim]
    user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        first: 'Zeus',
        perm: 'a:labors'
    )
    censor = Magma::Censor.new(
        user,
        'labors'
    )
    revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { country: 'Rome' } })
    expect(censor.censored_reasons(model, revisions)).to eq(
      ["Cannot revise restricted attribute :country on victim 'Apollodorus'"]
    )
  end

  it 'new record revisions not censored for users with restricted permissions' do
    model = Magma.instance.magma_projects[:labors].models[:victim]
    user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        first: 'Zeus',
        perm: 'a:labors'
    )
    censor = Magma::Censor.new(
        user,
        'labors'
    )
    revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { country: 'Rome' } })

    # This verifies that the code didn't just break from `restrict?`, a test precondition.
    # The censorship comes from attribute restriction, but there should be no record level restriction.
    expect(censor.censored_reasons(model, revisions)).to eq(
        ["Cannot revise restricted attribute :country on victim 'Apollodorus'"]
    )
  end

  it 'revisions censored for users with restricted model' do
    victim = create(:victim, name: 'Apollodorus', country: 'Greece', restricted: true)
    model = Magma.instance.magma_projects[:labors].models[:victim]
    user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        first: 'Zeus',
        perm: 'a:labors'
    )
    censor = Magma::Censor.new(
        user,
        'labors'
    )
    revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { name: 'Victim father' }})
    expect(censor.censored_reasons(model, revisions)).to eq(
        ["Cannot revise restricted victim 'Apollodorus'"])
  end
end

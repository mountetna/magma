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

  before(:each) do
    @project = create(:project, name: 'The Twelve Labors of Hercules')
  end

  it 'nothing censored for authorized users with unrestricted permissions' do
    victim = create(:victim, name: 'Apollodorus', country: 'Greece')
    model = Magma.instance.magma_projects[:labors].models[:victim]
    user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        name: 'Zeus',
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
        name: 'Zeus',
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
        name: 'Zeus',
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
    hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)
    monster = create(:monster, name: 'Lernean Hydra', labor: hydra)
    victim = create(:victim, name: 'Apollodorus', country: 'Greece', restricted: true, monster: monster)
    model = Magma.instance.magma_projects[:labors].models[:victim]
    user = Etna::User.new(
        email: 'zeus@mountolympus.org',
        name: 'Zeus',
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

  context 'shifted_date_time' do
    it 'revisions censored for users with restricted permissions' do
      victim = create(:victim, name: 'Apollodorus', birthday: '1000-01-01')
      model = Magma.instance.magma_projects[:labors].models[:victim]
      user = Etna::User.new(
          email: 'zeus@mountolympus.org',
          name: 'Zeus',
          perm: 'e:labors'
      )
      censor = Magma::Censor.new(
          user,
          'labors'
      )
      revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { birthday: '500-01-01' } })
      expect(censor.censored_reasons(model, revisions)).to eq(
        ["Cannot revise restricted attribute :birthday on victim 'Apollodorus'"]
      )
    end

    it 'new record revisions censored for users with restricted permissions' do
      model = Magma.instance.magma_projects[:labors].models[:victim]
      user = Etna::User.new(
          email: 'zeus@mountolympus.org',
          name: 'Zeus',
          perm: 'e:labors'
      )
      censor = Magma::Censor.new(
          user,
          'labors'
      )
      revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { birthday: '500-01-01' } })

      # This verifies that the code didn't just break from `restrict?`, a test precondition.
      # The censorship comes from attribute restriction, but there should be no record level restriction.
      expect(censor.censored_reasons(model, revisions)).to eq(
          ["Cannot revise restricted attribute :birthday on victim 'Apollodorus'"]
      )
    end

    it 'revisions not censored for users with privileged permissions' do
      victim = create(:victim, name: 'Apollodorus', birthday: '1000-01-01')
      model = Magma.instance.magma_projects[:labors].models[:victim]
      user = Etna::User.new(
          email: 'zeus@mountolympus.org',
          name: 'Zeus',
          perm: 'E:labors'
      )
      censor = Magma::Censor.new(
          user,
          'labors'
      )
      revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { birthday: '500-01-01' } })
      expect(censor.censored_reasons(model, revisions)).to eq(
        []
      )
    end

    it 'new record revisions not censored for users with privileged permissions' do
      model = Magma.instance.magma_projects[:labors].models[:victim]
      user = Etna::User.new(
          email: 'zeus@mountolympus.org',
          name: 'Zeus',
          perm: 'E:labors'
      )
      censor = Magma::Censor.new(
          user,
          'labors'
      )
      revisions = to_record_set(Labors::Victim, { 'Apollodorus' => { birthday: '500-01-01' } })

      expect(censor.censored_reasons(model, revisions)).to eq(
          []
      )
    end
  end
end

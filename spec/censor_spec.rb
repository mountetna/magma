require_relative '../lib/magma'
require 'pry'

describe Magma::Censor do
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
    expect(censor.censored?(model, [Magma::Revision.new(model, 'Apollodorus', {
        country: 'Rome'
    })])).to eq(nil)
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
    expect { |b|
        censor.censored?(model, [Magma::Revision.new(model, 'Apollodorus', {
            country: 'Rome'
        })], &b)
    }.to yield_with_args("Cannot revise restricted attribute :country on victim 'Apollodorus'")
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
    expect { |b|
        censor.censored?(model, [Magma::Revision.new(model, 'Apollodorus', {
            name: 'Victim father'
        })], &b)
    }.to yield_with_args("Cannot revise restricted victim 'Apollodorus'")
  end
end

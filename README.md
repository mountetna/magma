![Run tests](https://github.com/mountetna/magma/workflows/Run%20tests/badge.svg)

Magma is a data warehouse.

Data comes into Magma via JSON api (the /update and /loader endpoints) and command-line data loaders.

Data leaves Magma through JSON (the /retrieve and /query endpoints)

# Configuration

Magma is a Rack application, which means you can run it using any Rack-compatible server (e.g. Puma or Passenger).

Magma has a single YAML config file, `config.yml`; DO NOT TRACK this file, as it will hold all of your secrets. It uses the Etna::Application configuration syntax, e.g.:

    ---
    :test:
      :host: https://magma.test

    :development:
      :log_file: ./log/error.log

The environment is by default `development` but may be set via the environment variable MAGMA_ENV.

Some things you may configure:

    # This is the database configuration for the Sequel ORM (Documented at https://sequel.jeremyevans.net)
    # Magma uses the postgres adapter; it may not work with other databases.
    :db:
      :database: magma
      :host: localhost
      :adapter: postgres
      :user: magma
      :password: AAAAAAAA

    # A space-separated lists of magma project directories.
    # See below for details on creating a project.
    :project_path: ./projects/labors/

    # Where Magma will attempt to log - some server errors may not be trapped here.
    :log_file: log/error.log

    # Magma uses the `fog/aws` gem to connect to S3 for file storage,
    # and Carrierwave to manage uploads
    :storage:
      :provider: fog/aws
      :directory: 'my-magma-bucket'
      :expiration: 1440
      :credentials:
        :provider: 'AWS'
        :aws_access_key_id: 'AKIAETCETERA'
        :aws_secret_access_key: 'SoMeSecrEtK/Ey'
        :region: 'us-area-52'

    # The algorithm used by the authentication service (Janus) to sign tokens
    # and the public key to validate them.
    :token_algo: RS256
    :rsa_public: |
      -----BEGIN PUBLIC KEY-----
      KeYGoEsHeRE==
      -----END PUBLIC KEY-----

# Models

Here is an example Magma model:

    module Pancan
      class Sample < Magma::Model
        identifier :name, description: 'PANCAN id'
        attribute :mass, type: Float, description: 'Mass in grams'
      end
    end

Magma models use the Sequel ORM (http://sequel.jeremyevans.net/). Each model contains a list of attributes. Each attribute has a name (e.g. `patient_name`) and contains a piece of data - a String, Integer, Date, boolean, JSON object, etc. - or a link, a relationship to another model. Attributes may also include validations, add database indexes, and define specific behaviors.

Magma models are organized in a hierarchy - the root model must be called `Project`.

### Attributes

Attributes describe the data elements of the model, their interactions with other models, and so on.

  **_attribute_** - a generic attribute, representing any valid column name in the database

  **_identifier_** - a special attribute, a unique string identifier for records of this model type. Links between records are specified using the _identifier_ attribute. If no identifier is set the identifier defaults to the database _id_.

  <u>link types:</u>

  **_parent_** - an ancestor in a hierarchy, stored via a foriegn_key column in the model

  **_child_** - a child in a hierarchy, stored in the foreign model
  link - same as 'parent', just intended to represent other sorts of relations for clarity

  **_collection_** - an array of links to children

  <u>tables:</u>

  **_table_** - similar to a collection, except while a collection references a wholly separate model, a table is intended to essentially be a vector of values that loads with this model.

  <u>file types</u>:

  **_file_** - a generic binary document, stored on S3

  **_image_** - an image, similar to a document except it allows some thumbnailing

  <u>restriction</u>:
  **_restricted_** - a boolean attribute that determines whether this record is restricted.

## JSON api

  **POST _/update_** - accepts a JSON post in this format:

    {
      "project_name" : "labors",
      "revisions" : {
        "monster" : {
          "Nemean Lion" : {
            "species" : 'lion'
          }
        }
      }
    }

  **POST _/retrieve_** - accepts a JSON post in this format:

    {
      "project_name"    : "labors",
      "model_name"      : "labor",
      "record_names"    : [ "Nemean Lion" ],
      "attribute_names" : [ "name", "number", "completed" ]
    }

  In return you will get a payload like this:

    {
      "models": {
        "labor": {
          "documents": {
            "Nemean Lion": {
              "name": "Nemean Lion",
              "number": 1,
              "completed": true
            }
          },
          "template": {
            "name": "labor",
            "attributes": {
              "name": {
                "name": "name",
                "type": "String",
                "attribute_class": "Magma::Attribute",
                "display_name": "Name",
                "shown": true
              }
              // etc. for ALL attributes, not just requested
            }
          }
        },
        "identifier": "name",
        "parent": "project"
      }
    }

  **POST _/query_** - accepts JSON queries in Magma's Query language. See https://github.com/mountetna/magma/wiki/Query for more details.

### Migrations

Magma attempts to maintain a strict adherence between its models and
the database schema by suggesting migrations. These are written in the
Sequel ORM's migration language, not pure SQL, so they are fairly
straightforward to amend when Magma plans incorrectly.

To plan a new set of migrations, the first step is to amend your
models.  This also works in the case of entirely new models. Simply
sketch them out as described above, setting out the attributes each
model requires and creating links between them.

Once you've defined your models, you can execute `bin/magma plan` to
create a new migration. If you want to restrict your plan to a single
project you may do `bin/magma plan <project_name>`. Magma will output
ruby code for a migration using the Sequel ORM - you can save this in
your project's migration folder (e.g.
`project/my_project/migration/01_initial_migration.rb`).

After your migrations are in place, you can try to run them using `bin/magma
migrate`, which will attempt to run migrations that have not been run yet. If
you change your mind, you can roll backwards (depending on how reversible your
migration is) using `bin/magma migrate <migration version number>`.

### Validation

Magma models may define validations, which helps ensure the integrity of data
as it enters Magma (invalid data is rejected).  Magma has two basic forms of
validation. The first is attribute validation, which adds matchers to each
attribute on a model, e.g.:

    class MyModel < Magma::Model
      attribute :att1, type: String, match: /[r]egexp/
      attribute :att2, type: String, match: [ 'list', 'of', 'options' ]
    end

These validations are hard-coded into the model and may be hard to update. An
alternative method of validation is via a Magma::Dictionary, which allows a model
to be validated using data (records) from another model.

#### Dictionaries

You may define a dictionary relation as follows:

    class MyModel < Magma::Model
      attribute :att1
      attribute :att2

      dictionary DictModel, att1: :dict_att1, att2: :dict_att2
    end

A `my_model` record is valid if there is a matching entry in the dictionary
model, i.e., where `my_record.att1` matches `dict_record.att1` and
`my_record.att2` matches `dict_record.att2`. Here 'match' might mean
'equality', but a dictionary may also include a 'match' attribute.

    class DictModel < Magma::Model
      attribute :dict_att1
      match :dict_att2
    end

A match attribute contains json data like `{type,value}`. This allows us to construct more complex entries:

    # match any value in this Array
    { type: 'Array', value: [ 'x', 'y', 'z' ] }
    # match within this Range
    { type: 'Range', value: [ 0, 100 ] }
    # match this Regexp
    { type: 'Regexp', value: '^something$' }
    # match an ordinary value
    { type: 'String', value: 'something' }


### Data restriction

Magma will censor data from users who don't have "restricted" project access. Data can either be restricted by record or by attribute. To define a restricted model you may add a 'restricted' attribute to the model:

    class MyModel < Magma::Model
      restricted
    end

Any record where `record.restricted` is true will be censored for users without restricted access.

To define a restricted attribute on a model, you may add a 'restricted' flag to the attribute:

    class MyModel < Magma::Model
      attribute :some_att, restricted: true
    end

This attribute will always be censored from every record for users without restricted access.

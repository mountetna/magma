Magma is a data loader/model system. It has two components:

1. A gem. The gem exposes models which allow you to consume the database and run queries. It also allows you to update the schema.

2. A webserver. The webserver accepts JSON posts and updates the database accordingly.

Only the webserver can write to the database - the gem gives you custom loaders for your models, which produce JSON documents to send to the webserver.

# Design

Magma is meant to be a data warehouse - that is, a single point of entry from which you can get any piece of relevant biological data connected to your project. This includes the data resulting from your experiment, archived data produced by another project (e.g. TCGA), or generic annotation datasets available from standard sources (e.g. Uniprot).

Currently Magma is a Postgresql database connected to an Amazon S3 store. The Postgresql database contains summary data, such as cell or read counts resulting from an experiment, and also records such as an Ensembl transcriptome annotation. Any binary data (XML files, FCS files, etc.) goes into the S3 store.

(There is a hole here, because this system cannot provide or store large binary files.  I'm not sure what the best long-term solution is for this problem. A local fileserver capable of providing these files over http would be ideal and could hide behind magma the same way S3 does.)

## Models

Magma presents a model layer that is based on the Sequel ORM. Magma models are intended to be fairly stuffed-shirt representations of the data; schema-less data may fly in some places, but given the messy nature of bioinformatic data, fascist virtues should prevail here. This takes two major forms within Magma:

1) Each model is self-documented, describing each of the attribute columns, how it is intended to be used, and what a well-formed document should look like.

2) Certain data representations are encouraged. For example, representing graphs or cycles is currently out of scope; Magma works best on hierarchies of data.

### Attributes

Magma attempts to be self-documenting, so that any consumer is automatically given a complete description of the model. This is primarily achieved in the form of fixed 'attribute' definitions, which define certain kinds of relations on or between Magma models. So far, the possible attributes are:

  **_attribute_** - a generic attribute, representing any valid column name in the database

  <u>link types:</u>
  **_parent_** - an ancestor in a hierarchy, stored via a foriegn_key column in the model
  **_child_** - a child in a hierarchy, stored in the foreign model
  link - same as 'parent', just intended to represent other sorts of relations for clarity
  **_collection_** - an array of links to children

  <u>tables:</u>
  **_table_** - similar to a collection, except while a collection references a wholly separate model, a table is intended to essentially be a vector of values that loads with this model.

  <u>file types</u>:
  **_document_** - a generic binary document, stored on S3
  **_image_** - an image, similar to a document except it allows some thumbnailing

Connections between models are maintained by 'link' types, which are based on an 'identifier'.  Most Magma models should be labeled with a unique string identifier that is human-readable.  This makes it easier to load data, since we don't have to worry about hidden foreign key relationships, we can simply use the string identifier to link documents. E.g., if I want to link the Patient model with identifier "IPICRC001" to the Sample model with identifier "IPICRC001.T1", I can do that by identifier and let Magma worry about finding the appropriate foreign keys.

An exception is tables, which should contain a generic data vector (that is, not entities of particular interest). So, a model with an identifier might be a Gene or a Transcript, while the gene might contain a list of keyword Tags that don't need to be individually uniquely identified to a human; these must be referenced another way.

### JSON templates and documents

Magma provides access to these models in one of two ways:

1) A Ruby class (a 'model') or its instance representing a database row (a 'record')

2) A JSON description (a 'template') or a JSON object (a 'document') describing the model or record respectively

Ideally, the consumer presents a valid document (or list of documents) in JSON to Magma for entry into the database. Magma validates the document, publishes any errors and/or performs any inserts or updates into the database.

(This loop is currently non-existent. Instead, we just give the consumer read-write access via the Ruby models. This is bad and should be amended, especially as other data streams start to come online.)

### Migrations

Magma attempts to maintain a strict adherence between its models and the database schema by suggesting migrations. These are written in the Sequel ORM's migration language, not pure SQL, so they are fairly straightforward to amend when Magma plans incorrectly.

## Data input and loaders

Data can be passed into Magma in one of two ways:

1) Post a JSON/multipart document. This updates a single document and is expected to return immediately, useful for immediate data entry.

2) Post a batch update of JSON documents. This updates any number of documents asynchronously - that is, the consumer uploads a document or set of documents. Magma process the request in due time and reports back to the consumer if possible.

The first process is primarily intended to be used by user-facing web applications which might be responsible for immediate update and feedback.

The second process is primarily intended to be used by Loaders which describe ways to streamline data entry via binary files. For example, I might have a Loader that parses a certain file type into a particular representation in Magma - e.g., a Picard metrics file gets loaded into a Magma model 'SequenceMetrics'. The loader is responsible for correctly parsing the metrics file, transforming the items within into valid Magma documents, and then passing it in for batch update.

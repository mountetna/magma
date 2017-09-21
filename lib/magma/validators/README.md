## What is a Validator?

A Validator is an object that gets used to verify the integrity of data coming into Magma.

## How is a Validator used?

During an update/upload cycle a new Validator is created (see `/lib/magma/server/update.rb`). This new object is merely a container for Model Validators and Attribute Validators. As you can see from the file just referenced this new Validator is created at the beginning of update/upload cycle and is passed into `Magma::Revision.new`.

As well as passing in this top level Validator container, to the 'revision', we also pass in the model that corresponds to the revision. The model has attached to it the specific validator for it's class.

During this update/upload cycle we extract the appropriate Model Validators from the models and set them into the top level Validator container.

The reason for doing this is that it allows us to memoize our Model Validators. If we have multiple records that need to be updated that use the same Model, we can use the same Model Validator for each of those records.

Having the top level Validator container allows the memoization to happen and having the Model Validators attached to the Models allows us to easily specifiy which Model Validators go with which Model AND allows us to use multiple Model Validators per model OR use one class of Model Validators for a group of Models.

## About Attribute Validators.

When we are attempting to add a Model Validator to the top level Validator container we first check to see if the model we are referencing has a Model Validator set on it. If the model DOES NOT have a Model Validator set on it then the default `Magma::ModelValidator` gets used. This default `Magma::ModelValidator` will then use the Attribute Validators for validation.

In the `/lib/magma/attribute` folder you will see the base classes for the Attributes. A few of them will have `Validator < Magma::AttributeValidator` defined. If the default `Magma::ModelValidator` ednds up being used then it will run the corresponding attribute validators defined in the Attribute files (found in `/lib/magma/attribute`). This is the most basic and default validation that can happen.

## More information?

Each project (found in the `/projects` folder) should have a `validators` folder which contains (of course) the validators for that project (as well as the models specific to that project). There usually are README.md in those folders that give specific information about the project structure and validation.

### Dictionaries?

There is a special project called `/projects/dictionaries` this contains data that is used for/by validations. You should inspect the README.md in that folder next for details on what we validate against.

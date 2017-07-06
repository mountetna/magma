### Setting up a Postgres database for Magma.

Magma separates out projects using 'schema' in postgres. On the Ruby 'Sequel' side of things we namespace our models with the 'schema' in Postgres. For example, if I have a Postgres 'schema' called 'ipi' then a model for 'ipi' would look like thus:

```
module Ipi
  class Patient < Magma::Model
    ...
  end
end
```

As you can see we have namespaced the model with the name of the Postgres 'schema'. When we create a migration using the command:

```
$ bin/magma plan
```

t he command will look in the `./projects` folder and loop over the models. Since the models are namespaced those module names end up being converted into Postgres 'schema' names for the 'Sequel.migration'.

However, the Postgres 'schema' for the models are not created automatically. The creation of the Postgres 'schema' needs to be done manually for each project added to the system.

If we assume that the Postgres user is named 'developer' and that the ENV is 'test', 'development', or 'production', then the following commands will set up an appropriate Postgres 'schema' for your project.

```
$ sudo -i -u postgres
$ psql
postgres=# drop database magma_[ENV];
postgres=# create database magma_[ENV];
postgres=# \c magma_[ENV];
magma_[ENV]=# REVOKE ALL ON schema public FROM public;
magma_[ENV]=# REVOKE ALL ON DATABASE magma_[ENV] FROM public;
magma_[ENV]=# GRANT CONNECT ON DATABASE magma_[ENV] TO developer;
magma_[ENV]=# CREATE SCHEMA [PROJECT NAME];
magma_[ENV]=# GRANT CREATE, USAGE ON SCHEMA [PROJECT NAME] TO developer;
magma_[ENV]=# GRANT CREATE, USAGE ON SCHEMA public TO developer;
magma_[ENV]=# \q
$ exit
```

One final note: If you notice, we REVOKE permissions on the 'schema' public, for security reasons. However, we do use the public 'schema' to hold project specific information. So we do need to be able to write to it, thus we have the GRANT command of `public TO developer`;

### More information.

Look at the `./projects` directory README.md for more info related to creating magma models and migrations and for an example of a project setup.

### Another method for migration.

Here is another method for running the migration. BUT you should use the Magma command (see the README.md in the `./projects` directory).

`$ sequel -m [MIGRATION FOLDER] postgres://[USER]:[PASS]@[HOST]/[DATABASE NAME]?search_path=[SCHEMA]`

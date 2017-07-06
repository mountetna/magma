## Project setup

To add projects to Magma, simply create a new folder in the /projects directory with your project name:

`projects/my_project`

For magma to load this project you must add this project to the project_path for your environment in /config.yml

```
:development:
  :db:
    :database: magma_development
    :host: localhost
    :adapter: postgres
    :user: developer
    :password: blah-de-blah
  :project_path: ./projects/ipi/
```

### Environments

To specify your environment for any of the below commands, merely set the MAGMA_ENV environment variable, e.g.:

```
$ MAGMA_ENV=test bin/magma plan
$ MAGMA_ENV=production rake db:migrate
```

The default environment is 'development'

### Creating models

Within this projects folder you may create a 'models' folder:

`projects/my_project/models`

with your project models defined (ideally one per .rb):

`projects/my_project/models/my_model.rb`

### Creating loaders

If you write custom data loaders for your project, they should also go into your project directory:

`project/my_project/loaders`

### Creating metrics

If you write data metrics for your project, they should also go into your project directory:

`project/my_project/metrics`

### Requirement order

If you need to explicitly specify the order of loading of these items or otherwise want to setup requirements, you can create a requirements.rb which should explicitly require files using require_relative; otherwise magma will attempt to require all files in models/, metrics/ and loaders/ in arbitrary order.

`projects/my_project/requirements.rb`

### Creating migrations

Once you have defined some models, you will probably want to create some
database migrations for them. You can use the magma 'plan' command to help
you do this:

`$ bin/magma plan`

This will output a Sequel migration that you can save to a migration. **NOTE**that Magma will generate a plan for ALL projects on the project_path in config.yml - you almost certainly do not want to do this, so restrict your project_path appropriately when planning, e.g.:

```
:production:
  :project_path: ./projects/my_project
```

and NOT:

```
:production:
  :project_path: ./projects/my_project ./projects/my_other_project
```

**See the README.md in the ./projects/example/migrations folder for more details**

### Saving a migration

First you should make a migrations folder for your project:

`projects/my_project/migrations`

Then save the output from 'plan' to a migration.rb:

`$ bin/magma plan > projects/my_project/migrations/01_my_first_migration.rb`

### Running migrations

Once you have setup your migrations, you can run them just by typing:

`$ bin/magma migrate`

### More information.

Look at the `./db` directory README.md for more info related to creating Postgres 'schema' and how it relates to the models and migrations.
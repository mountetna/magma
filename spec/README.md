## How to setup the rspec unit testing.

This set of tests need a DB to function correctly.

1. We want to specify the DB to use in the `./config.yml` file.

Here is an excerpt you may to use. For an initial DB set up should have a look at `./db/README.md`.

```
:test:
  :db:
    :database: magma_test
    :host: localhost
    :adapter: postgres
    :user: [DB_USER]
    :password: [DB PASSWORD]

  :project_path: ./spec/labors
```

As you can see the `:project_path` is set at the `./spec/labors` folder. This folder contains the models that the unit tests will need.

2. Set up the `magma_test` DB with the `labors` schema and tables.

If the `labors` schema and tables are not yet set up you should run the migrations. You can have a look in `./spec/labors/migrations` to view what we are going to do to the DB. There are two methods to run the migrations.

  * By using the Magma command. You will need to make sure that the `:test` environment is defined in `./config.yml` from the previous step.

`$ MAGMA_ENV=test bin/magma migrate`

  * By using the Ruby Sequel command. The generic form of the following command is listed in the `./db/README.md`.

`$ sequel -m ./spec/labors/migration postgres://[USER]:[PASS]@[HOST]/magma_test?search_path=labors`

In both cases the DB should be setup and the 'labors' schema should exist. Again, the step to do that are listed in `./db/README.md`.

3. Now you are ready to run the tests.

`$ rspec ./spec`

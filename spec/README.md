## Setting up and Running the rspec unit testing.

### Creating a test database.

```
$ sudo -i -u postgres
$ psql
postgres=# create database magma_test;
postgres=# \c magma_test;
magma_test=# REVOKE ALL ON schema public FROM public;
magma_test=# REVOKE ALL ON DATABASE magma_test FROM public;
magma_test=# GRANT CONNECT, CREATE, TEMPORARY ON DATABASE magma_test TO developer;
magma_test=# CREATE SCHEMA labors;
magma_test=# GRANT CREATE, USAGE ON SCHEMA labors TO developer;
magma_test=# GRANT CREATE, USAGE ON SCHEMA public TO developer;
magma_test=# \q
```

### Migrate the test DB.

`$ sequel -m ./spec/labors/migrations postgres://someusername:someuserpassword@localhost/magma_test?search_path=labors`

### Adding a test configuration.

Add the following to your `config.yml`
```
:test:
  :db:
    :database: magma_test
    :host: localhost
    :adapter: postgres
    :encoding: unicode
    :username: someusername
    :password: somepassword
    :pool: 5
    :timeout: 5000

  :project_path: ./spec/labors

  :magma:
    :host: http://magma.test
```

### Running the test.

From the project folder run:

`$ rspec spec;`

or

`$ rspec ./spec/[FILE_NAME];`

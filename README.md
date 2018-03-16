# Assessment Network Metadata Repository

[![Build Status](https://travis-ci.org/a15k/metadata-repository.svg?branch=master)](https://travis-ci.org/a15k/metadata-repository)

Repository for assessment network metadata

## Dev Database Setup

In psql:
```sql
CREATE USER a15k_meta WITH SUPERUSER PASSWORD 'a15k_meta_secret_password';
```

In the metadata repository's dir:
```sh
rake db:setup
```

# Extensions used for creating federated view of different years

## General

See [General Data Modeling](../../core-platform/doc/Datamodels.md#invalid-record)

Used by [](members/mcr_combine_tables)

## Combining multiple sources and optional columns

Source can be an array of columns rather than one column.

The following block will define a column named `ssa3`. The tool
will look for columns named either `cnty_cd`, or `bene_county_cd`, or
`ssa_county` to map to the new `ssa3` column. If neither of these three columns 
is found, a new column will be created and filled with NULL values.

Without `optional: true`, if an appropriate source column is not found,
an exception will be raised.

```yaml
- ssa3:
    optional: true
    description: Social Security Administration (SSA) three digit code for county
    reference: https://www.nber.org/research/data/ssa-federal-information-processing-series-fips-state-and-county-crosswalk
    source:
      - cnty_cd
      - bene_county_cd
      - ssa_county
```


## Exclude

Using `exclude` can exclude certain tables matching patern from teh federated 
view.

The following example creates a view by combining all tables matching either
`cms.mbsf_ab*` or `cms.mcr_bene_*` pattern, but excluding the table named 
`mbsf_ab_2015`:

```yaml
ps:
  create:
    type: view
    from:
      - cms.mbsf_ab*
      - cms.mcr_bene_*
    exclude:
      - mbsf_ab_2015


```

## Cast

It is possible to define custom casts from one type to another. When tables
to be combined into a single view have columns containing corresponding data
but of different types, it is possible to cast all of them to the same type.

In the following example:

```yaml
- dob:
    type: date
    cast:
      "character varying": "public.parse_date({column_name})"
      numeric: "to_date(to_char({column_name}, '00000000'), 'YYYYMMDD')"
      *: {column_name}::DATE
```

* If a source column is of type `DATE`, it will be left as is
* If the source column is of numeric type, the code 

      to_date(to_char({column_name}, '00000000'), 'YYYYMMDD')
  will be used to transform the source value
* If the source column has type `character varying`, then the function
   `public.parse_date` will be called to transform the value
* For all other types a simple PostgreSQL cast will be attempted 




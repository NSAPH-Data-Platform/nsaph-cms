# Python package to manipulate health (CMS) data

```{seealso}
 [Python Module Index](modindex)
```

## Package cms

* [fts2yaml](members/fts2yaml.rst) is a generic
    parser for [FTS](#parsing-fts) format for both Medicaid and Medicare.
* [create_schema_config](members/create_schema_config.rst) is used
    to interpret options to introspect raw files or parse FTS
* [registry](members/registry.rst) Command line tool to create and/or update
    data models for raw CMS data (See 
    [create_schema_config](members/create_schema_config.rst) for options)
* [random_selector](members/random_selector.rst) Selects random lines
  from a CSV-like file
* [random_selector](members/mcr_create_test_data) Selects random lines
  from a set of CMS files described by an [FTS file](../../../fts)
* [medicare data loader](members/mcr_data_loader.rst)  Subclass of generic 
    [Data Loader](../../core-platform/doc/members/data_loader.rst) 
    aware of the raw Medicare CMS
    data structure. Matches FTS and DAT files.


## Package cms.tools 

* [CMS Test data generator](members/mcr_create_test_data) Selects random lines
  from a set of CMS files described by an [FTS file](../../../fts)
* [mcr_combine_tables](members/mcr_combine_tables.rst) Command-line
    tool to combine disparate tables with raw medicare CMS data
    into a single consolidated view. 
    See [details](Medicare.md#combining-raw-files-into-a-single-view)
* [medpar_converter](members/medpar_converter.rst) Converter for CMS `DAT` 
    files described by `FTS` to `CSV`
* [mcr_file](members/mcr_file.rst) Module to manipulate with a single
    Medicare CMS DAT file
* [mcr_fts2csv](members/mcr_fts2csv.rst) Simple converter from FWF format to CSV
* [mcr_fts2db](members/mcr_fts2db.rst) Loader of FWF data into the database
* [mcr_registry](members/mcr_registry.rst) Common content for the 
    Medicare data model YAML file
* [mcr_sas](members/mcr_sas.rst) Abstract class to look for and process 
    Medicare files from 1999 to 2010
* [mcr_sas2db](members/mcr_sas2db.rst) Loader looks for SAS 7BDAT files
* [mcr_sas2yaml](members/mcr_sas2yaml.rst) Introspector for SAS 7BDAT
    files, generating 
    [YAML data model](../../core-platform/doc/Datamodels.md) for each file

>>> This package contains code that was written to try to extract
corrupted medicare data for 2015. Ultimately, this attempt
was unsuccessful.

```{seealso}
 [Python Module Index](modindex)
```


## Additional details

### Parsing FTS

File transfer summary (FTS) document contains information about 
the data extract. These are plain text files containing
information such as the number of
columns in the data extract, number of rows and the size of the
data file. The FTS document provides the
starting positions, the length and the generic format of 
each of the column (such as character, numeric or date)  

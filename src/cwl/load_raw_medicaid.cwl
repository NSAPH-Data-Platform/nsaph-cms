#!/usr/bin/env cwl-runner
### Patient Summary Loader
#  Copyright (c) 2021. Harvard University
#
#  Developed by Research Software Engineering,
#  Faculty of Arts and Sciences, Research Computing (FAS RC)
#  Author: Michael A Bouzinier
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

cwlVersion: v1.2
class: CommandLineTool
baseCommand: [python, -m, nsaph.loader.data_loader]
requirements:
  InlineJavascriptRequirement: {}

doc: |
  This tool loads patient summary data into a database.
  It should be run after the data is inspected and
  data model is created from FTS files


inputs:
  registry:
    type: File?
    inputBinding:
      prefix: --registry
    doc: |
      A path to the data model file
  domain:
    type: string
    doc: the name of the domain
    inputBinding:
      prefix: --domain
  table:
    type: string
    doc: the name of the table being populated
    inputBinding:
      prefix: --table
  database:
    type: File
    doc: Path to database connection file, usually database.ini
    inputBinding:
      prefix: --db
  connection_name:
    type: string
    doc: The name of the section in the database.ini file
    inputBinding:
      prefix: --connection
  incremental:
    type: boolean
    inputBinding:
      prefix: --incremental
    doc: |
      if defined, then the data ingestion is incremental.
      Transactions are committed after every file is processed
      and files that have already been processed are skipped
  input:
    type: Directory
    inputBinding:
      prefix: --data
    doc: |
      A path to directory, containing unpacked CMS
      files. The tool will recursively look for data files
      according to provided pattern
  pattern:
    type: string
    inputBinding:
      prefix: --pattern
  threads:
    type: int
    default: 4
    doc: number of threads, concurrently writing into the database
    inputBinding:
      prefix: --threads
  page_size:
    type: int
    default: 1000
    doc: explicit page size for the database
    inputBinding:
      prefix: --page
  log_frequency:
    type: long
    default: 100000
    doc: informational logging occurs every specified number of records
    inputBinding:
      prefix: --log
  limit:
    type: long?
    doc: |
      if specified, the process will stop after ingesting
      the specified number of records
    inputBinding:
      prefix: --limit
  depends_on:
    type: File?
    doc: a special field used to enforce dependencies and execution order



outputs:
  log:
    type: File
    outputBinding:
      glob: "*.log"
  errors:
    type: stderr

stderr:  $("load-" + inputs.table + ".err")


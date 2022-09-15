#!/usr/bin/env cwl-runner
### Loader for raw CMS Medicare data
#  Copyright (c) 2022. Harvard University
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
baseCommand: [python, -m, cms.tools.mcr_fts2db]
requirements:
  InlineJavascriptRequirement: {}

doc: |
  This tool loads CMS Medicare data from *.dat files accompanied by FTS
  files, describing their metadata

inputs:
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
  input:
    type: Directory
    inputBinding:
      prefix: --data
    doc: |
      A path to directory, containing unpacked CMS
      files. The tool will recursively look for data files
      according to provided pattern
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

arguments:
  - valueFrom: "--reset"
  - valueFrom: "--incremental"
  - valueFrom: "cms.yaml"
    prefix: --registry



outputs:
  log:
    type: File
    outputBinding:
      glob: "*.log"
  registry:
    type: File
    outputBinding:
      glob: "cms.yaml"
  err:
    type: stderr

stderr: "load_medicare_data.err"


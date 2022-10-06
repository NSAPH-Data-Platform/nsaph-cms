#!/usr/bin/env cwl-runner
### Table/View Initializer
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
  This tool executes DDL to drop and recreate
  a table, a view or a materialized view in the database.
  By default, it is assumed it is run for Medicaid domain,
  parameter `domain` must be defined if using a different domain


inputs:
  #$import: db.yaml
  table:
    type: string
    doc: the name of the table to be created
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
  sloppy:
    type: boolean
    default: false
    inputBinding:
      prefix: --sloppy
  domain:
    type: string
    default:  "medicaid"
    inputBinding:
      prefix: --domain
  action:
    type: string?
    inputBinding:
      prefix: --action
  registry:
    type: string?
    inputBinding:
      prefix: --registry
  input_data:
    type: File?
    inputBinding:
      prefix: --data
  limit:
    type: string?
    inputBinding:
      prefix: --limit

  depends_on:
    type:
      - File?
      - File[]
    doc: a special field used to enforce dependencies and execution order

arguments:
    - valueFrom: "--reset"


outputs:
  log:
    type: File
    outputBinding:
      glob: "*.log"
  errors:
    type: stderr

stderr: $("create_" + inputs.table + ".err")


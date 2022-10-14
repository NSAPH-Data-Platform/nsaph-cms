#!/usr/bin/env cwl-runner
### Materialized View Creator
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
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}

doc: |
  This tool is a shortcut to create a materialized view and build
  all indices associated with the view

inputs:
  database:
    type: File
    doc: Path to database connection file, usually database.ini
  connection_name:
    type: string
    doc: The name of the section in the database.ini file
  input:
    type: File?
  depends_on:
    type: File?
    doc: a special field used to enforce dependencies and execution order

steps:
  create:
    run: create.cwl
    doc: Load 2015 data (processed by Yun)
    in:
      table:
        valueFrom: "mbsf_ab_2015"
      domain:
        valueFrom: "cms"
      registry:
        valueFrom: "mbsf_ab_2015.yaml"
      database: database
      input_data: input
      connection_name: connection_name
    when: $(inputs.input_data != null)
    out: [ log, errors ]

  index:
    run: index.cwl
    doc: Build indices
    in:
      depends_on: create/log
      table:
        valueFrom: "mbsf_ab_2015"
      registry:
        valueFrom: "mbsf_ab_2015.yaml"
      domain:
        valueFrom: "cms"
      incremental:
        valueFrom: $(true)
      database: database
      connection_name: connection_name

    out: [ log, errors ]

  vacuum:
    run: vacuum.cwl
    doc: Vacuum the view
    in:
      depends_on: index/log
      table:
        valueFrom: "mbsf_ab_2015"
      registry:
        valueFrom: "mbsf_ab_2015.yaml"
      domain:
        valueFrom: "cms"
      database: database
      connection_name: connection_name
    out: [ log, errors ]

outputs:
  create_log:
    type: File
    outputSource: create/log
  index_log:
    type: File
    outputSource: index/log
  vacuum_log:
    type: File
    outputSource: vacuum/log

  create_err:
    type: File
    outputSource: create/errors
  index_err:
    type: File
    outputSource: index/errors
  vacuum_err:
    type: File
    outputSource: vacuum/errors

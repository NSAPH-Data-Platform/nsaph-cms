#!/usr/bin/env cwl-runner
### Process Medicare inpatient admissions data inside the database
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
class: Workflow

requirements:
  SubworkflowFeatureRequirement: {}
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}

doc: |
  This workflow processes raw Medicare  admissions (aka Medpar or inpatient
  admissions - ip) data. The assumed initial state
  is that raw data (medpar files) are already in the database. We assume
  that the data for each year is in a separate table. The first step
  combines these disparate tables into a single view, creating uniform
  columns.

inputs:
  database:
    type: File
    doc: Path to database connection file, usually database.ini
  connection_name:
    type: string
    doc: The name of the section in the database.ini file
  limit:
    type: string?
    doc: limit number of records processed (for debugging)
  depends_on:
    type: File?
    doc: a special field used to enforce dependencies and execution order

steps:
  create_ip:
    run: medicare_combine_tables.cwl
    doc: >
      Combines patient summaries from disparate summary tables
      (one table per year) into a single view: medicare.ip
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "ip"
    out:  [ log, errors ]

  create_admissions_table:
    run: create.cwl
    doc: Create empty admissions table based on medicare.ip view
    in:
      database: database
      connection_name: connection_name
      domain:
        valueFrom: "medicare"
      table:
        valueFrom: "admissions"
      depends_on: create_ip/log
    out: [ log, errors ]
  
  populate_admissions_table:
    run: create.cwl
    doc: Creates `Enrollments` Table from the view
    in:
      depends_on: create_admissions_table/log
      table:
        valueFrom: "admissions"
      domain:
        valueFrom: "medicare"
      action:
        valueFrom: "insert"
      database: database
      limit: limit
      connection_name: connection_name
    out: [ log, errors ]

  index_admissions_table:
    run: index.cwl
    doc: Build indices
    in:
      depends_on: populate_admissions_table/log
      table:
        valueFrom: "admissions"
      domain:
        valueFrom: "medicare"
      incremental:
        valueFrom: $(false)
      database: database
      connection_name: connection_name

    out: [ log, errors ]

  vacuum_admissions_table:
    run: vacuum.cwl
    doc: Vacuum the view
    in:
      depends_on: index_admissions_table/log
      table:
        valueFrom: "admissions"
      domain:
        valueFrom: "medicare"
      database: database
      connection_name: connection_name
    out: [ log, errors ]


outputs:
  ip_create_log:
    type: File
    outputSource: create_ip/log
  ip_create_err:
    type: File
    outputSource: create_ip/errors

  adm_create_log:
    type: File
    outputSource: create_admissions_table/log
  adm_create_err:
    type: File
    outputSource: create_admissions_table/errors

  adm_populate_log:
    type: File
    outputSource: populate_admissions_table/log
  adm_populate_err:
    type: File
    outputSource: populate_admissions_table/errors

  adm_index_log:
    type: File
    outputSource: index_admissions_table/log
  adm_index_err:
    type: File
    outputSource: index_admissions_table/errors

  adm_vacuum_log:
    type: File
    outputSource: vacuum_admissions_table/log
  adm_vacuum_err:
    type: File
    outputSource: vacuum_admissions_table/errors

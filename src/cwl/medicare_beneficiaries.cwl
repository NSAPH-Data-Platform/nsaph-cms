#!/usr/bin/env cwl-runner
### Medicare Beneficiaries data in-database processing pipeline
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
  MultipleInputFeatureRequirement: {}

doc: |
  This workflow processes raw Medicare beneficiaries summary data.
  The assumed initial state
  is that raw data is already in the database. We assume that the data
  for each year is in a separate table. The first step
  combines these disparate tables into a single view, creating uniform
  columns.

inputs:
  database:
    type: File
    doc: Path to database connection file, usually database.ini
  connection_name:
    type: string
    doc: The name of the section in the database.ini file
  depends_on:
    type: File?
    doc: a special field used to enforce dependencies and execution order

steps:
  create_d:
    run: medicare_combine_tables.cwl
    doc: >
      Combines patient summaries from disparate summary tables
      (one table per year) into a single view
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "mbsf_d"
    out:  [ log, errors ]

  index_d:
    run: index.cwl
    doc: Build indices
    in:
      depends_on: create_d/log
      domain:
        valueFrom: "medicare"
      table:
        valueFrom: "mbsf_d"
      database: database
      connection_name: connection_name

    out: [ log, errors ]

  vacuum_d:
    run: vacuum.cwl
    doc: Vacuum the view
    in:
      depends_on: index_d/log
      domain:
        valueFrom: "medicare"
      table:
        valueFrom: "mbsf_d"
      database: database
      connection_name: connection_name
    out: [ log, errors ]

  create_ps:
    run: medicare_combine_tables.cwl
    doc: >
      Combines patient summaries from disparate summary tables
      (one table per year) into a single view
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "ps"
    out:  [ log, errors ]

  create__ps_view:
    run: matview.cwl
    doc: Create _ps materialized view from ps
    in:
      table:
        valueFrom: "_ps"
      database: database
      connection_name: connection_name
      domain:
        valueFrom: "medicare"
      depends_on: create_ps/log
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

  create_bene_view:
    run: create.cwl
    doc: Creates preliminary beneficiaries view
    in:
      table:
        valueFrom: "_beneficiaries"
      database: database
      connection_name: connection_name
      domain:
        valueFrom: "medicare"
      depends_on: create__ps_view/vacuum_log
    out: [ log, errors ]

  create_bene_table:
    run: matview.cwl
    doc: Creates `Beneficiaries` Table from the view
    in:
      depends_on: create_bene_view/log
      table:
        valueFrom: "beneficiaries"
      domain:
         valueFrom: "medicare"
      database: database
      connection_name: connection_name
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

  create_enrlm_view:
    run: create.cwl
    doc: Creates preliminary _enrollments view
    in:
      table:
        valueFrom: "_enrollments"
      database: database
      connection_name: connection_name
      domain:
        valueFrom: "medicare"
      depends_on:
      - create__ps_view/vacuum_log
      - create_bene_table/vacuum_log
      - index_d/log
    out: [ log, errors ]

  create_enrlm_table:
    run: matview.cwl
    doc: Creates `Enrollments` Table from the view
    in:
      depends_on: create_enrlm_view/log
      table:
        valueFrom: "enrollments"
      domain:
         valueFrom: "medicare"
      database: database
      connection_name: connection_name
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

outputs:
  d_create_log:
    type: File
    outputSource: create_d/log
  d_index_log:
    type: File
    outputSource: index_d/log
  d_vacuum_log:
    type: File
    outputSource: vacuum_d/log

  d_create_err:
    type: File
    outputSource: create_d/errors
  d_index_err:
    type: File
    outputSource: index_d/errors
  d_vacuum_err:
    type: File
    outputSource: vacuum_d/errors

  ps_create_log:
    type: File
    outputSource: create_ps/log
  ps_create_err:
    type: File
    outputSource: create_ps/errors
  ps2_create_log:
    type: File
    outputSource: create__ps_view/create_log
  ps2_create_err:
    type: File
    outputSource: create__ps_view/create_err
  ps2_index_log:
    type: File
    outputSource: create__ps_view/index_log
  ps2_vacuum_log:
    type: File
    outputSource: create__ps_view/vacuum_log
  ps2_index_err:
    type: File
    outputSource: create__ps_view/index_err
  ps2_vacuum_err:
    type: File
    outputSource: create__ps_view/vacuum_err


  # bene_view
  bene_view_log:
    type: File
    outputSource: create_bene_view/log
  bene_view_err:
    type: File
    outputSource: create_bene_view/errors
  # bene_table  
  bene_table_create_log:
    type: File
    outputSource: create_bene_table/create_log
  bene_table_index_log:
    type: File
    outputSource: create_bene_table/index_log
  bene_table_vacuum_log:
    type: File
    outputSource: create_bene_table/vacuum_log
  bene_table_create_err:
    type: File
    outputSource: create_bene_table/create_err
  bene_table_index_err:
    type: File
    outputSource: create_bene_table/index_err
  bene_table_vacuum_err:
    type: File
    outputSource: create_bene_table/vacuum_err

  # enrollments view
  enrlm_view_log:
    type: File
    outputSource: create_enrlm_view/log
  enrlm_view_err:
    type: File
    outputSource: create_enrlm_view/errors

  # enrollments table
  enrlm_table_create_log:
    type: File
    outputSource: create_enrlm_table/create_log
  enrlm_table_index_log:
    type: File
    outputSource: create_enrlm_table/index_log
  enrlm_table_vacuum_log:
    type: File
    outputSource: create_enrlm_table/vacuum_log
  enrlm_table_create_err:
    type: File
    outputSource: create_enrlm_table/create_err
  enrlm_table_index_err:
    type: File
    outputSource: create_enrlm_table/index_err
  enrlm_table_vacuum_err:
    type: File
    outputSource: create_enrlm_table/vacuum_err

  
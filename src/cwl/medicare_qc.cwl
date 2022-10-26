#!/usr/bin/env cwl-runner
### Creates helper tables for Medicare QC
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
  This workflow creates helper tables to be used in Quality Checks (QC)
  for Medicare data

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
  create_enrl_qc_view:
    run: create.cwl
    doc: >
      Creates a joined view with Beneficiaries and Enrollments tables
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "qc_enrl_bene"
      domain:
         valueFrom: "medicare"
    out:  [ log, errors ]

  create_adm_qc_view:
    run: create.cwl
    doc: >
      Creates a union of admissions validated records and records
      discarded because of validation issues
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "qc_adm_union"
      domain:
         valueFrom: "medicare"
    out:  [ log, errors ]

  create_enrollments_qc_table:
    run: matview.cwl
    doc: Creates a table with aggregate data for beneficiaries and enrollments
    in:
      depends_on: create_enrl_qc_view/log
      table:
        valueFrom: "qc_enrollments"
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

  create_admissions_qc_table:
    run: matview.cwl
    doc: Creates a table with aggregate data for inpatient admissions
    in:
      depends_on: create_adm_qc_view/log
      table:
        valueFrom: "qc_admissions"
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
  ev_create_log:
    type: File
    outputSource: create_enrl_qc_view/log
  ev_create_err:
    type: File
    outputSource: create_enrl_qc_view/errors
  av_create_log:
    type: File
    outputSource: create_adm_qc_view/log
  av_create_err:
    type: File
    outputSource: create_adm_qc_view/errors

  enrollmen343_create_log:
    type: File
    outputSource: create_enrollments_qc_table/create_log
  enrollmen343_index_log:
    type: File
    outputSource: create_enrollments_qc_table/index_log
  enrollmen343_vacuum_log:
    type: File
    outputSource: create_enrollments_qc_table/vacuum_log
  enrollmen343_create_err:
    type: File
    outputSource: create_enrollments_qc_table/create_err
  enrollmen343_index_err:
    type: File
    outputSource: create_enrollments_qc_table/index_err
  enrollmen343_vacuum_err:
    type: File
    outputSource: create_enrollments_qc_table/vacuum_err

  admission697_create_log:
    type: File
    outputSource: create_admissions_qc_table/create_log
  admission697_index_log:
    type: File
    outputSource: create_admissions_qc_table/index_log
  admission697_vacuum_log:
    type: File
    outputSource: create_admissions_qc_table/vacuum_log
  admission697_create_err:
    type: File
    outputSource: create_admissions_qc_table/create_err
  admission697_index_err:
    type: File
    outputSource: create_admissions_qc_table/index_err
  admission697_vacuum_err:
    type: File
    outputSource: create_admissions_qc_table/vacuum_err

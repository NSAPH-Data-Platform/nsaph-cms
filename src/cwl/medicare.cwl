#!/usr/bin/env cwl-runner
### Medicare in-database processing pipeline
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
  This workflow processes raw Medicare data. The assumed initial state
  is that raw data is already in the database. We assume that the data
  for each year is in a separate set of tables consisting of at least
  two tables: patient summary and inpatient admissions. The first step
  combines these disparate tables into a single view, creating uniform
  columns.

inputs:
  database:
    type: File
    doc: Path to database connection file, usually database.ini
  connection_name:
    type: string
    doc: The name of the section in the database.ini file

steps:
  enrollments:
    run: medicare_beneficiaries.cwl
    doc: >
      Process beneficiaries enrollment data
    in:
      database: database
      connection_name: connection_name
    out:
      - ps_create_log
      - ps_create_err
      - ps2_create_log
      - ps2_create_err
      - bene_view_log
      - bene_view_err
      - bene_table_create_log
      - bene_table_index_log
      - bene_table_vacuum_log
      - bene_table_create_err
      - bene_table_index_err
      - bene_table_vacuum_err
      - enrlm_view_log
      - enrlm_view_err
      - enrlm_table_create_log
      - enrlm_table_index_log
      - enrlm_table_vacuum_log
      - enrlm_table_create_err
      - enrlm_table_index_err
      - enrlm_table_vacuum_err

  admissions:
    run: medicare_admissions.cwl
    doc: Process medicare inpatient admissions (aka Medpar) data
    in:
      database: database
      connection_name: connection_name
    out:
      - ip_create_log
      - ip_create_err
      - adm_create_log
      - adm_create_err
      - adm_populate_log
      - adm_populate_err
      - adm_index_log
      - adm_index_err
      - adm_vacuum_log
      - adm_vacuum_err


outputs:
  ## Generated by nsaph/util/cwl_collect_outputs.py from medicare_beneficiaries.cwl:
    ps_create_log:
      type: File
      outputSource: enrollments/ps_create_log
    ps_create_err:
      type: File
      outputSource: enrollments/ps_create_err
    ps2_create_log:
      type: File
      outputSource: enrollments/ps2_create_log
    ps2_create_err:
      type: File
      outputSource: enrollments/ps2_create_err
    bene_view_log:
      type: File
      outputSource: enrollments/bene_view_log
    bene_view_err:
      type: File
      outputSource: enrollments/bene_view_err
    bene_table_create_log:
      type: File
      outputSource: enrollments/bene_table_create_log
    bene_table_index_log:
      type: File
      outputSource: enrollments/bene_table_index_log
    bene_table_vacuum_log:
      type: File
      outputSource: enrollments/bene_table_vacuum_log
    bene_table_create_err:
      type: File
      outputSource: enrollments/bene_table_create_err
    bene_table_index_err:
      type: File
      outputSource: enrollments/bene_table_index_err
    bene_table_vacuum_err:
      type: File
      outputSource: enrollments/bene_table_vacuum_err
    enrlm_view_log:
      type: File
      outputSource: enrollments/enrlm_view_log
    enrlm_view_err:
      type: File
      outputSource: enrollments/enrlm_view_err
    enrlm_table_create_log:
      type: File
      outputSource: enrollments/enrlm_table_create_log
    enrlm_table_index_log:
      type: File
      outputSource: enrollments/enrlm_table_index_log
    enrlm_table_vacuum_log:
      type: File
      outputSource: enrollments/enrlm_table_vacuum_log
    enrlm_table_create_err:
      type: File
      outputSource: enrollments/enrlm_table_create_err
    enrlm_table_index_err:
      type: File
      outputSource: enrollments/enrlm_table_index_err
    enrlm_table_vacuum_err:
      type: File
      outputSource: enrollments/enrlm_table_vacuum_err
  ## Generated by nsaph/util/cwl_collect_outputs.py from medicare_admissions.cwl:
    ip_create_log:
      type: File
      outputSource: admissions/ip_create_log
    ip_create_err:
      type: File
      outputSource: admissions/ip_create_err
    adm_create_log:
      type: File
      outputSource: admissions/adm_create_log
    adm_create_err:
      type: File
      outputSource: admissions/adm_create_err
    adm_populate_log:
      type: File
      outputSource: admissions/adm_populate_log
    adm_populate_err:
      type: File
      outputSource: admissions/adm_populate_err
    adm_index_log:
      type: File
      outputSource: admissions/adm_index_log
    adm_index_err:
      type: File
      outputSource: admissions/adm_index_err
    adm_vacuum_log:
      type: File
      outputSource: admissions/adm_vacuum_log
    adm_vacuum_err:
      type: File
      outputSource: admissions/adm_vacuum_err
#!/usr/bin/env cwl-runner
### Full Medicaid Processing Pipeline
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
  This workflow ingests Medicaid data, provided by
  Centers for Medicare & Medicaid Services (CMS)
  to researches. The expected input format is
  Medicaid Analytic eXtract (MAX) data.

  The workflow parses File transfer summary (FTS) files,
  loads the raw data into a PostgreSQL DBMS and then processes
  the data to prepare it for using by NSAPH researches.
  See [documentation](../Medicaid.md) for detailed
  information.

inputs:
  database:
    type: File
    doc: Path to database connection file, usually database.ini
  connection_name:
    type: string
    doc: The name of the section in the database.ini file
  input:
    type: Directory
    doc: |
      A path to directory, containing unpacked CMS
      files. The tool will recursively look for data files
      according to provided pattern

steps:
  states:
    run: ensure_resource.cwl
    doc: |
      Ensures the presence of `us_states` table in the database.
      The table contains mapping between state names, ids
      (two letter abbreviations), FIPS codes and
      [ISO-3166-2 codes](https://en.wikipedia.org/wiki/ISO_3166-2)
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "us_states"
    out: [log]
  iso:
    run: ensure_resource.cwl
    doc: |
      Ensures the presence of `us_iso` table in the database.
      The table provides a mapping between states, counties and zip
      codes. It contains FIPS and
      [ISO-3166-2 codes](https://en.wikipedia.org/wiki/ISO_3166-2)
    in:
      database: database
      connection_name: connection_name
      table:
        valueFrom: "us_iso"
    out: [log]
  fts:
    run: parse_fts.cwl
    in:
      input: input
      output:
        valueFrom: cms.yaml
    out: [log, model, errors]

  load_ps:
    run: ingest_cms.cwl
    doc: Loads Patient Summaries
    in:
      registry: fts/model
      domain:
        valueFrom: "cms"
      table:
        valueFrom: "ps"
      input: input
      database: database
      connection_name: connection_name
      incremental:
        valueFrom: $(true)
    out:
      - reset_log
      - create_log
      - index_log
      - vacuum_log
      - reset_err
      - create_err
      - index_err
      - vacuum_err

  load_ip:
    run: ingest_cms.cwl
    doc: Loads inpatient admissions
    in:
      depends_on: load_ps/vacuum_log
      registry: fts/model
      domain:
        valueFrom: "cms"
      table:
        valueFrom: "ip"
      input: input
      database: database
      connection_name: connection_name
      incremental:
        valueFrom: $(true)
    out:
      - reset_log
      - create_log
      - index_log
      - vacuum_log
      - reset_err
      - create_err
      - index_err
      - vacuum_err

  create_beneficiaries:
    run: matview.cwl
    doc: Creates `Beneficiaries` Table
    in:
      depends_on: load_ip/vacuum_log
      table:
        valueFrom: "beneficiaries"
      database: database
      connection_name: connection_name
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

  create_monthly_view:
    run: matview.cwl
    doc: Creates internally used `Monthly View`
    in:
      depends_on: create_beneficiaries/vacuum_log
      table:
        valueFrom: "monthly"
      database: database
      connection_name: connection_name
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

  create_enrollments:
    run: matview.cwl
    doc: Creates `Enrollment` Table
    in:
      depends_on: create_monthly_view/vacuum_log
      table:
        valueFrom: "enrollments"
      database: database
      connection_name: connection_name
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

  prepare_eligibility:
    run: create.cwl
    doc: |
      Creates `_Eligibility` View,
      prerequisit for creation of Eligibility table
    in:
      depends_on: create_enrollments/vacuum_log
      table:
        valueFrom: "_eligibility"
      database: database
      connection_name: connection_name
    out:
      - log
      - errors

  create_eligibility:
    run: matview.cwl
    doc: Creates `Eligibility` Table
    in:
      depends_on: prepare_eligibility/log
      table:
        valueFrom: "eligibility"
      database: database
      connection_name: connection_name
    out:
      - create_log
      - index_log
      - vacuum_log
      - create_err
      - index_err
      - vacuum_err

  load_admissions:
    run: ingest_cms.cwl
    doc: Processes and loads inpatient admissions
    in:
      depends_on: create_eligibility/vacuum_log
      domain:
        valueFrom: "medicaid"
      table:
        valueFrom: "admissions"
      input: input
      database: database
      connection_name: connection_name
      incremental:
        valueFrom: $(true)
    out:
      - reset_log
      - create_log
      - index_log
      - vacuum_log
      - reset_err
      - create_err
      - index_err
      - vacuum_err

outputs:
  resource1_log:
    type: File
    outputSource: states/log
  resource2_log:
    type: File
    outputSource: iso/log
  parse_log:
    type: File?
    outputSource: fts/log

  ps_reset_log:
    type: File
    outputSource: load_ps/reset_log
  ps_create_log:
    type: File
    outputSource: load_ps/create_log
  ps_index_log:
    type: File
    outputSource: load_ps/index_log
  ps_vacuum_log:
    type: File
    outputSource: load_ps/vacuum_log
  ip_reset_log:
    type: File
    outputSource: load_ip/reset_log
  ip_create_log:
    type: File
    outputSource: load_ip/create_log
  ip_index_log:
    type: File
    outputSource: load_ip/index_log
  ip_vacuum_log:
    type: File
    outputSource: load_ip/vacuum_log

  ben_create_log:
    type: File
    outputSource: create_beneficiaries/create_log
  ben_index_log:
    type: File
    outputSource: create_beneficiaries/index_log
  ben_vacuum_log:
    type: File
    outputSource: create_beneficiaries/vacuum_log
  mnth_create_log:
    type: File
    outputSource: create_monthly_view/create_log
  mnth_index_log:
    type: File
    outputSource: create_monthly_view/index_log
  mnth_vacuum_log:
    type: File
    outputSource: create_monthly_view/vacuum_log
  enrlm_create_log:
    type: File
    outputSource: create_enrollments/create_log
  enrlm_index_log:
    type: File
    outputSource: create_enrollments/index_log
  enrlm_vacuum_log:
    type: File
    outputSource: create_enrollments/vacuum_log
  elgb_prepare_log:
    type: File
    outputSource: prepare_eligibility/log
  elgb_create_log:
    type: File
    outputSource: create_eligibility/create_log
  elgb_index_log:
    type: File
    outputSource: create_eligibility/index_log
  elgb_vacuum_log:
    type: File
    outputSource: create_eligibility/vacuum_log

  admissions_reset_log:
    type: File
    outputSource: load_admissions/reset_log
  admissions_create_log:
    type: File
    outputSource: load_admissions/create_log
  admissions_index_log:
    type: File
    outputSource: load_admissions/index_log
  admissions_vacuum_log:
    type: File
    outputSource: load_admissions/vacuum_log

## ERROR LOGS ###########################################

  parse_err:
    type: File
    outputSource: fts/errors

  ps_reset_err:
    type: File
    outputSource: load_ps/reset_err
  ps_create_err:
    type: File
    outputSource: load_ps/create_err
  ps_index_err:
    type: File
    outputSource: load_ps/index_err
  ps_vacuum_err:
    type: File
    outputSource: load_ps/vacuum_err
  ip_reset_err:
    type: File
    outputSource: load_ip/reset_err
  ip_create_err:
    type: File
    outputSource: load_ip/create_err
  ip_index_err:
    type: File
    outputSource: load_ip/index_err
  ip_vacuum_err:
    type: File
    outputSource: load_ip/vacuum_err


  ben_create_err:
    type: File
    outputSource: create_beneficiaries/create_err
  ben_index_err:
    type: File
    outputSource: create_beneficiaries/index_err
  ben_vacuum_err:
    type: File
    outputSource: create_beneficiaries/vacuum_err
  mnth_create_err:
    type: File
    outputSource: create_monthly_view/create_err
  mnth_index_err:
    type: File
    outputSource: create_monthly_view/index_err
  mnth_vacuum_err:
    type: File
    outputSource: create_monthly_view/vacuum_err
  enrlm_create_err:
    type: File
    outputSource: create_enrollments/create_err
  enrlm_index_err:
    type: File
    outputSource: create_enrollments/index_err
  enrlm_vacuum_err:
    type: File
    outputSource: create_enrollments/vacuum_err
  elgb_create_err:
    type: File
    outputSource: create_eligibility/create_err
  elgb_prepare_err:
    type: File
    outputSource: prepare_eligibility/errors
  elgb_index_err:
    type: File
    outputSource: create_eligibility/index_err
  elgb_vacuum_err:
    type: File
    outputSource: create_eligibility/vacuum_err
  admissions_reset_err:
    type: File
    outputSource: load_admissions/reset_err
  admissions_create_err:
    type: File
    outputSource: load_admissions/create_err
  admissions_index_err:
    type: File
    outputSource: load_admissions/index_err
  admissions_vacuum_err:
    type: File
    outputSource: load_admissions/vacuum_err

### Workflow to grant read (SELECT) privilege to all users in NSAPH admin role
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
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}

doc: |
  This workflow executes an SQL statement in the database to
  This is a wrapper around the tool to be called from Airflow DAG.

inputs:
  database:
    type: File
    doc: Path to database connection file, usually database.ini
  connection_name:
    type: string
    doc: The name of the section in the database.ini file
  owner:
    type: string
    default: nsaph_admin

steps:
  grant:
    run: alter_database.cwl
    doc: |
      Grants read access to the members of NSAPH group for newly created
      or updated tables
    in:
      database: database
      connection_name: connection_name
      sql:
        valueFrom: $(["CALL public.owner_to('" + inputs.owner + "');"])
      owner: owner
    out:
      - log
      - err


outputs:
  grant_log:
    type: File
    outputSource: grant/log
  grant_err:
    type: File
    outputSource: grant/err


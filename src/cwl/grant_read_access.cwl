### Utility to grant read (SELECT) privilege to all users in NSAPH admin role
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
baseCommand: [python, -m, nsaph.util.psql]
requirements:
  InlineJavascriptRequirement: {}


doc: |
  This tool executes an SQL statement in the database to grant
  read priviligies to NSAPH users (memebrs of group nsaph_admin)

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
  depends_on:
    type: File?
    doc: a special field used to enforce dependencies and execution order
  sql:
    type: string[]
    default:
      - "call public.grant_select('nsaph_admin');"
    inputBinding:
      position: 3

outputs:
  log:
    type: stdout
  err:
    type: stderr

stderr: "grant.err"
stdout: "grant.log"


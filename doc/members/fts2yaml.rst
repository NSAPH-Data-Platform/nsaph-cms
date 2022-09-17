:orphan:


Parser for FTS files that accompany CMS data from ResDac
========================================================

See also `What is FTS <../../../../fts.html>`_  for more details about FTS

.. contents:: Table of Contents
   :depth: 4
   :local:


The parser tries to recognize a type of a medicare or a medicaid CMS file and
extract metadata

Abstract class for CMS FTS file
-------------------------------
.. autoclass:: cmsFTS
    :show-inheritance:
    :members:
    :undoc-members:

Concrete subclass describing Medicare FTS file
----------------------------------------------
.. autoclass:: cms.fts2yaml.MedicareFTS
    :members:
    :undoc-members:
    :show-inheritance:


Concrete subclass describing Medicaid FTS file
----------------------------------------------
.. autoclass:: cms.fts2yaml.MedicaidFTS
    :members:
    :undoc-members:
    :show-inheritance:


Abstract class describing a column in a CMS data file
-----------------------------------------------------
.. autoclass:: cms.fts2yaml.FTSColumn
    :members:
    :undoc-members:
    :show-inheritance:


Concrete subclass describing a column in a Medicare data file
-------------------------------------------------------------
.. autoclass:: cms.fts2yaml.MedicareFTSColumn
    :members:
    :undoc-members:
    :show-inheritance:

Concrete subclass describing a column in a Medicaid data file
-------------------------------------------------------------
.. autoclass:: cms.fts2yaml.MedicaidFTSColumn
    :members:
    :undoc-members:
    :show-inheritance:

Concrete subclass describing a column not present in the original data but that should be generated in the database
-------------------------------------------------------------------------------------------------------------------
.. autoclass:: cms.fts2yaml.AliasColumn
    :members:
    :undoc-members:
    :show-inheritance:

Helper Classes
--------------

.. autoclass:: cms.fts2yaml.ColumnReader
    :members:
    :undoc-members:
    :show-inheritance:

.. autoclass:: cms.fts2yaml.ColumnAttribute
    :members:
    :undoc-members:
    :show-inheritance:


Helper Functions
--------------

.. autofunction:: cms.fts2yaml.mcr_type

.. autofunction:: cms.fts2yaml.width


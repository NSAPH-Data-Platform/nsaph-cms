from setuptools import setup, find_packages

with open("README.md", "r") as readme:
    long_description = readme.read()


setup(
    name='cms',
    version="0.0.3.22",
    url='https://gitlab-int.rc.fas.harvard.edu/rse/francesca_dominici/tools/cms',
    license='',
    author='Michael Bouzinier',
    author_email='mbouzinier@g.harvard.edu',
    description='CMS Data Pipeline (Upstream)',
    long_description = long_description,
    long_description_content_type = "text/markdown",
    #py_modules = [''],
    package_dir={
        "cms": "./src/python/cms",
        "cms.sql": "./src/sql"
    },
    packages=["cms", "cms.tools", "cms.sql"],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: Harvard University :: Development",
        "Operating System :: OS Independent"],
    install_requires=[
        'nsaph>=0.0.3.12',
        'nsaph_utils >= 0.0.5.18',
    ],
    package_data = {
        '': ["**/*.yaml"],
        "cms.sql":["*.sql"]
    }
)

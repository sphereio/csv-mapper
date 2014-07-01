# csv-mapper

[![Build Status](https://travis-ci.org/sphereio/csv-mapper.png?branch=master)](https://travis-ci.org/sphereio/csv-mapper) [![NPM version](https://badge.fury.io/js/csv-mapper.png)](http://badge.fury.io/js/csv-mapper) [![Dependency Status](https://david-dm.org/sphereio/csv-mapper.png?theme=shields.io)](https://david-dm.org/sphereio/csv-mapper) [![devDependency Status](https://david-dm.org/sphereio/csv-mapper/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/csv-mapper#info=devDependencies)

This library is designed to take input CSV file and map it to output CSV files according to the  very flexible JSON mapping.

# Setup

* install [NodeJS](http://support.sphere.io/knowledgebase/articles/307722-install-nodejs-and-get-a-component-running) (platform for running application)

### From scratch

* install [npm]((http://gruntjs.com/getting-started)) (NodeJS package manager, bundled with node since version 0.6.3!)
* install [grunt-cli](http://gruntjs.com/getting-started) (automation tool)
*  resolve dependencies using `npm`
```bash
$ npm install
```
* build javascript sources
```bash
$ grunt build
```

### Install CLI Globally

To make the application globally available, please do:

```bash
sudo npm install csv-mapper -g
```

## Documentation

### Usage

    Usage: csv-mapper --mapping [mapping.json]

    Options:
      --help, -h            Shows usage info and exits.
      --inCsv               The input product CSV file (optional, STDIN would be used if not specified).
      --outCsv              The output product CSV file (optional, STDOUT would be used if not specified).
      --csvDelimiter        CSV delimiter (by default ,).
      --csvQuote            CSV quote (by default ").
      --mapping, -m         Mapping JSON file or URL.                                                                        [required]
      --group               The column group that should be used.                                                            [string]  [default: "default"]
      --additionalOutCsv    Addition output CSV files separated by comma `,` and optionally prefixed with `groupName:`.
      --timeout             Set timeout for requests                                                                         [default: 300000]
      --dryRun, -d          No external side-effects would be performed                                                      [default: false]
      --attemptsOnConflict  Number of attempts to update the project in case of conflict (409 HTTP status)                   [default: 10]
      --disableAsserts      disable asserts (e.g.: required)

The only required argument is `mapping` (see below).

### Mapping File

Mapping is a json document that has following structure:

    {
      "description": "Test mapping",
      "columnMapping": [{
          "type": "addColumn",
          "toCol": "constant",
          "valueTransformers": [
            {"type": "constant", "value": "Foo"}
          ]
        },
        ...
      ]
    }

There are several concepts, that you need to be aware of, when you are defining the mapping:

In the top-level object of mapping you can specify following properties:

* **description** - String (Optional) - Some info about this mapping
* **groupColumn** - Object (Optional) - the grouping column definition
  * **col** - String - the name of the column
  * **type** - String - One of: **constant**, **asc**, **desc**

#### Columns Mappings

They are used to create/delete columns. You can use column mappings of following types:

* **copyFromOriginal** - Copies all columns from the original CSV (default priority: 1000)
  * **includeCols** - Array of strings (Optional) - whitelist for the column names
  * **excludeCols** - Array of strings (Optional) - blacklist for the column names
  * **priority** - Int (Optional) - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings (Optional) - to which column groups does this column mapping belongs (more info about groups below)
* **removeColumns** - Removes columns (default priority: 1500)
  * **cols** - Array of strings - names of the columns that should be removed from the resulting CSV
  * **priority** - Int (Optional) - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings (Optional) - to which column groups does this column mapping belongs (more info about groups below)
* **addColumn** - Adds new column (default priority: 3000)
  * **toCol** - String - the name of the column
  * **valueTransformers** - Array of value transformers (Optional) - they generate value for this column (see below for the available value transformers)
  * **priority** - Int (Optional) - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings (Optional) - to which column groups does this column mapping belongs (more info about groups below)
* **transformColumn** - Transforms some existing column (default priority: 2000)
  * **fromCol** - String - from which column should initial value be taken (value would be passed to the value transformers)
  * **toCol** - String - the name of the column
  * **valueTransformers** - Array of value transformers (Optional) - they transform value for this column (see below for the available value transformers)
  * **priority** - Int (Optional) - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings (Optional) - to which column groups does this column mapping belongs (more info about groups below)

#### Value Transformers

Value transformers are used to generate/transform column value.
The output of one transformer in the list would be passed as input to the next one.
If input is undefined, all transformers will ignore it and pass it to the next transformer (so if you want to make sure that column has some non-empty value, please use `regexp` value transformer).

Here is the list of standard value transformers:

* **constant** - returns some constant value (ignores input)
  * **value** - Anything - value to return
* **print** - returns input value and prints it to the console in the process (useful for the debugging)
* **randomDelay** - adds random delay during transformation
  * **minMs** - Number
  * **maxMs** - Number
* **column** - returns value of specified column (ignores input)
  * **col** - String - the name of the column
* **upper** - transforms input value to upper case
* **lower** - transforms input value to lower case
* **slugify** - returns slugified input value
* **random** - generates random output (ignores input)
  * **size** - Int - the size of the generated string
  * **chars** - String - the range of characters that should be used in the resulting string
* **counter** - returns the index of the row
  * **startAt** - Number (Optional) - the first index (by default `0`)
* **groupCounter** - returns the index of the row within a group
  * **startAt** - Number (Optional) - the first index (by default `0`)
* **oncePerGroup** - the child value transformers are evaluated only one time for each group
  * **name** - String - the name of the cached evaluationResults
  * **valueTransformers** - Array of value transformers - they would be evaluated only one time per group
* **regexp** - searches input string with the help of regular expression and replaces found matches
  * **find** - String - regular expression to find
  * **replace** - String - replacement text (you can use placeholders like `$1` to insert groups)
* **lookup** - a lookup table that will  return matching value based on the input key
  * **header**  - Boolean - whether lookup CSV contains header
  * **keyCol** - Int or String - lookup CSV key column name or index
  * **valueCol** - Int or String - lookup CSV value column name or index
  * **file** - String (Optional) - lookup CSV location (can be a file path or URL)
  * **csvDelimiter** - String (Optional)
  * **csvQuote** - String (Optional)
  * **values** - Array of Arrays or Strings (Optional) - an alternative to file, that allows to define lookup CSV contents in-place
* **multipartString** - retuns a string that consists of multiple parts
  * **parts** - Array of objects - The definitions of the string parts
    * **size** - Int - the size of the string part (if no padding is specified and resulting string has different size, then mapping would be interrupted with error)
    * **pad**  - String (Optional) - the padding that is used, if resulting string is too small
    * **fromCol**  - String (Optional) - the name of the column with initial value for this part
    * **valueTransformers** - Array of value transformers (Optional) - they transform value for this string part

Here is the list of workflow value transformers:

* **required** - Interrupts mapping process if input value is empty or undefined
* **fallback** - Evaluates provided value transformers one after another and returns the first non-undefined value
  * **valueTransformers** - Array of value transformers - the child value transformers that would be used to get first successful value

#### Column Groups

Then you define column mappings, you can also provide an array of groups. Then when you are performing actual mapping
you can provide a set of additional output files. Each additional output file should have the column group name - this
will define, which columns this file contains. Here is an example:

    csv-mapper --mapping mapping.json --additionalOutCsv a:/path/to/a.csv,b:/path/to/b.csv

in this case `/path/to/a.csv`, for instance, will contain only columns that have group `a`.

There are 2 special group names:

* **default** - always used, if group is not specified
* **virtual** - columns with this group can be used to create columns that are not written to any file, but used to define other columns

## Examples

You can find example mapping in [the project itself](https://github.com/sphereio/csv-mapper/blob/master/test-data/test-mapping.json).
If you are in the project root, you can map an example CSV file like this:

    csv-mapper --mapping test-data/test-mapping.json --inCsv test-data/test-large.csv

## Tests
Tests are written using [jasmine](http://pivotal.github.io/jasmine/) (behavior-driven development framework for testing javascript code). Thanks to [jasmine-node](https://github.com/mhevery/jasmine-node), this test framework is also available for node.js.

To run tests, simple execute the *test* task using `grunt`.
```bash
$ grunt test
```

## Contributing
In lieu of a formal styleguide, take care to maintain the existing coding style. Add unit tests for any new or changed functionality. Lint and test your code using [Grunt](http://gruntjs.com/).
More info [here](CONTRIBUTING.md)

## Releasing
Releasing a new version is completely automated using the Grunt task `grunt release`.

```javascript
grunt release // patch release
grunt release:minor // minor release
grunt release:major // major release
```

## License
Copyright (c) 2014 Oleg Ilyenko
Licensed under the MIT license.

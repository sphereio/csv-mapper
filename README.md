# sphere-product-mapper

[![Build Status](https://travis-ci.org/sphereio/sphere-product-mapper.png?branch=master)](https://travis-ci.org/sphereio/sphere-product-mapper) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-product-mapper/badge.png?branch=master)](https://coveralls.io/r/sphereio/sphere-product-mapper?branch=master) [![Dependency Status](https://david-dm.org/sphereio/sphere-product-mapper.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-product-mapper) [![devDependency Status](https://david-dm.org/sphereio/sphere-product-mapper/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-product-mapper#info=devDependencies)

This app is designed to take input CSV file and map it to output CSV files according to the mapping.

## Getting Started
Install the module with: `npm install sphere-product-mapper`

## Setup

* create `config.js`
  * make `create_config.sh`executable

    ```
    chmod +x create_config.sh
    ```
  * run script to generate `config.js`

    ```
    ./create_config.sh
    ```
* configure github/hipchat integration (see project *settings* in guthub)
* install travis gem `gem install travis`
* add encrpyted keys to `.travis.yml`
 * add sphere project credentials to `.travis.yml`

        ```
        travis encrypt [xxx] --add SPHERE_PROJECT_KEY
        travis encrypt [xxx] --add SPHERE_CLIENT_ID
        travis encrypt [xxx] --add SPHERE_CLIENT_SECRET
        ```
  * add hipchat credentials to `.travis.yml`

        ```
        travis encrypt [xxx]@Sphere --add notifications.hipchat.rooms
        ```

## Documentation

### Usage

    Usage: csv-mapper --mapping [mapping.json]

    Options:
      --help, -h          Shows usage info and exits.
      --projectKey, -k    Sphere.io project key (required if you use sphere-specific value transformers).
      --clientId, -i      Sphere.io HTTP API client id (required if you use sphere-specific value transformers).
      --clientSecret, -s  Sphere.io HTTP API client secret (required if you use sphere-specific value transformers).
      --inCsv             The input product CSV file (optional, STDIN would be used if not specified).
      --outCsv            The output product CSV file (optional, STDOUT would be used if not specified).
      --csvDelimiter      CSV delimiter (by default ,).
      --csvQuote          CSV quote (by default ").
      --mapping, -m       Mapping JSON file or URL.                                                                        [required]
      --group             The column group that should be used.                                                            [string]  [default: "default"]
      --additionalOutCsv  Addition output CSV files separated by comma `,` and optionally prefixed with `groupName:`.
      --timeout           Set timeout for requests                                                                         [default: 300000]
      --dryRun, -d        No external side-effects would be performed (also sphere services would generate mocked values)  [default: false]

The only required argument is `mapping` (see below). If you want to use SPHERE.IO specific value transformers in the mapping,
then you also need to specify `projectKey`, `clientId`, `clientSecret`.

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

There are several concepts that you need to be aware of, when you defining a mapping:

#### Columns Mappings

They are used to create/delete columns. You can use column mappings of following types:

* **copyFromOriginal** - Copies all columns from the original CSV (default priority: 1000)
  * **includeCols** - Array of strings (Optional) - whitelist for the column names
  * **excludeCols** - Array of strings (Optional) - blacklist for the column names
  * **priority** - Int - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings - to which column groups does this column mapping belongs (more info about groups below)
* **removeColumns** - Removes columns (default priority: 1500)
  * **cols** - Array of strings - names of the columns that should be removed from the resulting CSV
  * **priority** - Int - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings - to which column groups does this column mapping belongs (more info about groups below)
* **addColumn** - Adds new column (default priority: 3000)
  * **toCol** - String - the name of the column
  * **valueTransformers** - Array of value transformers - they generate value for this column (see below for the available value transformers)
  * **priority** - Int - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings - to which column groups does this column mapping belongs (more info about groups below)
* **transformColumn** - Transforms some existing column (default priority: 2000)
  * **fromCol** - String - from which column should initial value be taken (value would be passed to the value transformers)
  * **toCol** - String - the name of the column
  * **valueTransformers** - Array of value transformers - they generate value for this column (see below for the available value transformers)
  * **priority** - Int - all columns are evaluated according to their priority, columns with lower priority are evaluated earlier (it has nothing to do with the position in the CSV file)
  * **groups** - Array of strings - to which column groups does this column mapping belongs (more info about groups below)

## Examples

You can find example mapping in [the project itself](https://github.com/sphereio/sphere-product-mapper/blob/master/test-data/test-mapping.json).
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

## Styleguide
We <3 CoffeeScript here at commercetools! So please have a look at this referenced [coffeescript styleguide](https://github.com/polarmobile/coffeescript-style-guide) when doing changes to the code.

## License
Copyright (c) 2014 Oleg Ilyenko
Licensed under the MIT license.

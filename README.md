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

## Examples
_(Coming soon)_

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

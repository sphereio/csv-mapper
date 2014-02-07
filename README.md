# sphere-product-mapper
============================

[![Build Status](https://travis-ci.org/sphereio/sphere-product-mapper.png?branch=master)](https://travis-ci.org/sphereio/sphere-product-mapper) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-product-mapper/badge.png)](https://coveralls.io/r/sphereio/sphere-product-mapper) [![Dependency Status](https://david-dm.org/sphereio/sphere-product-mapper.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-product-mapper) [![devDependency Status](https://david-dm.org/sphereio/sphere-product-mapper/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-product-mapper#info=devDependencies)

This app is designed to take products export files and map/restructure them. During this process, original product would be updated with the SKU reference to the new product.

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
_(Coming soon)_

## Tests
Tests are written using [jasmine](http://pivotal.github.io/jasmine/) (behavior-driven development framework for testing javascript code). Thanks to [jasmine-node](https://github.com/mhevery/jasmine-node), this test framework is also available for node.js.

To run tests, simple execute the *test* task using `grunt`.
```bash
$ grunt test
```

## Examples
_(Coming soon)_

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

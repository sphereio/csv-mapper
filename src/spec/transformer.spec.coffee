Q = require 'q'
fs = require 'q-io/fs'
_ = require('underscore')._

transformer = require('../main').transformer

Mapper = require('../main').Mapper

describe 'Transformers', ->
  describe 'ConstantTransformer', ->
    it 'should always return the same value', (done) ->
      transformer.ConstantTransformer.create transformer.defaultTransformers,
        value: 'foo'
      .then (t) ->
        t.transform 'Hello World!', {}
      .then (result) ->
        expect(result).toEqual 'foo'
        done()
      .fail (error) ->
        done(error)
      .done()

  describe 'PrintTransformer', ->
    it 'should always return the input value', (done) ->
      transformer.PrintTransformer.create transformer.defaultTransformers, {}
      .then (t) ->
        t.transform 'Hello World!', {}
      .then (result) ->
        expect(result).toEqual 'Hello World!'
        done()
      .fail (error) ->
        done(error)
      .done()

  describe 'AdditionalOptionsWrapper', ->
    it 'should pass extra options to the delegate', ->
      delegate =
        create: (transformers, options) ->
          expect(options.foo).toEqual 'bar'
          expect(options.baz).toEqual 10
        supports: (options) ->
          expect(options.foo).toEqual 'bar'
          expect(options.baz).toEqual 10

      wrapper = new transformer.AdditionalOptionsWrapper delegate,
        foo: 'bar'

      wrapper.supports
        baz: 10
      wrapper.create null,
        baz: 10
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

  describe 'ColumnTransformer', ->
    it 'should return the value of specified column', (done) ->
      transformer.ColumnTransformer.create transformer.defaultTransformers,
        col: "fooCol"
      .then (t) ->
        t.transform 'Hello World!',
          fooCol: "TestStr"
      .then (result) ->
        expect(result).toEqual 'TestStr'
        done()
      .fail (error) ->
        done(error)
      .done()

  describe 'RequiredTransformer', ->
    it 'should reject undefined values', (done) ->
      transformer.RequiredTransformer.create transformer.defaultTransformers, {}
      .then (t) ->
        t.transform undefined, {}
      .then (result) ->
        done("No error")
      .fail (error) ->
        expect(error.message).toEqual 'Value is empty.'
        done()
      .done()

    it 'should reject empty values', (done) ->
      transformer.RequiredTransformer.create transformer.defaultTransformers, {}
      .then (t) ->
        t.transform '  ', {}
      .then (result) ->
        done("No error")
      .fail (error) ->
        expect(error.message).toEqual 'Value is empty.'
        done()
      .done()

    it 'should reject undefined values', (done) ->
      transformer.RequiredTransformer.create transformer.defaultTransformers, {}
      .then (t) ->
        t.transform 'foo', {}
      .then (result) ->
        expect(result).toEqual 'foo'
        done()
      .fail (error) ->
        done(error)
      .done()

  describe 'FallbackTransformer', ->
    it 'should return first non-undefined value', (done) ->
      transformer.FallbackTransformer.create transformer.defaultTransformers,
        valueTransformers: [
          {type: 'column', col: 'foo'}
          {type: 'column', col: 'bar'}
          {type: 'column', col: 'baz'}
        ]
      .then (t) ->
        t.transform 'Hello World!',
          bar: "BarStr"
          baz: "BazStr"
      .then (result) ->
        expect(result).toEqual 'BarStr'
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
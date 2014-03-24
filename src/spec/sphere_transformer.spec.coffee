Q = require 'q'
fs = require 'q-io/fs'
_ = require('underscore')._

{defaultTransformers} = require('../main').transformer
{SphereSequenceTransformer, RepeatOnDuplicateSkuTransformer, SphereService, DuplicateSku} = require('../main').sphere_transformer

describe 'Sphere transformers', ->
  mockSphereService = () ->
    getAndIncrementCounter: (options) ->
      Q(12345)
    repeatOnDuplicateSku: (options) ->
      expect(options.attempts).toBe 5
      options.valueFn()
    checkUniqueSku: (sku) ->
      expect(sku).toEqual 'foo'
      Q(sku)

  describe 'SphereSequenceTransformer', ->
    it 'should get and incremented counter from sphere service', (done) ->
      mock = mockSphereService()

      spyOn(mock, 'getAndIncrementCounter').andCallThrough()

      SphereSequenceTransformer.create defaultTransformers,
        sphereService: mock
        name: "foo"
        initial: 0
        max: 100
        min: 0
        increment: 1
        rotate: false
      .then (t) ->
        t.transform 'Hello World!',
          index: 0
          groupFirstIndex: 0
          groupContext: {}
          groupRows: 1
      .then (result) ->
        expect(mock.getAndIncrementCounter).toHaveBeenCalled()
        expect(result).toEqual 12345
        done()
      .fail (error) ->
        done(error)
      .done()

  describe 'RepeatOnDuplicateSkuTransformer', ->
    it 'should check whether SKU already exists', (done) ->
      mock = mockSphereService()

      spyOn(mock, 'checkUniqueSku').andCallThrough()

      RepeatOnDuplicateSkuTransformer.create defaultTransformers,
        sphereService: mock
        attempts: 5
        valueTransformers: [{type: "constant", value: "foo"}]
      .then (t) ->
        t.transform 'Hello World!',
          index: 0
          groupFirstIndex: 0
          groupContext: {}
          groupRows: 1
      .then (result) ->
        expect(mock.checkUniqueSku).toHaveBeenCalled()
        expect(result).toEqual 'foo'
        done()
      .fail (error) ->
        console.info error.stack
        done(error.stack)
      .done()
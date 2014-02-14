Q = require 'q'
fs = require 'q-io/fs'
_ = require('underscore')._

util = require '../lib/util'

describe 'util.parseAdditionalOutCsv', ->
  it 'should return an empty array if unpit is undfined', () ->
    expect(util.parseAdditionalOutCsv(undefined)).toEqual []

  it 'should parse single element', () ->
    expect(util.parseAdditionalOutCsv("group:/file/path")).toEqual [
      {group: 'group', file: '/file/path'}
    ]

  it 'should parse multiple elements', () ->
    expect(util.parseAdditionalOutCsv("group1:/file/path1,group2:/file/path2")).toEqual [
      {group: 'group1', file: '/file/path1'}
      {group: 'group2', file: '/file/path2'}
    ]
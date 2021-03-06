upgradeDB = require '../../lib/upgradeDB'
testUtils = require '../testUtils'
Keystore = require('../../lib/model/keystore').Keystore
Client = require('../../lib/model/clients').Client
User = require('../../lib/model/users').User
Visualizer = require('../../lib/model/visualizer').Visualizer
Q = require 'q'
should = require 'should'

describe 'Upgrade DB Tests', ->

  describe '.upgradeDB', ->

    func1Complete = false
    func2Complete = false

    mockUpgradeFunc1 = () ->
      defer = Q.defer()
      setTimeout ->
        if func2Complete
          throw new Error 'Funtions ran non sequentially'
        else
          func1Complete = true
          defer.resolve()
      , 10 * global.testTimeoutFactor
      return defer.promise

    mockUpgradeFunc2 = () ->
      defer = Q.defer()
      func2Complete = true
      defer.resolve()
      return defer.promise

    it 'should run each upgrade function sequentially', (done) ->
      upgradeDB.upgradeFuncs.length = 0
      upgradeDB.upgradeFuncs.push
        description: 'mock func 1'
        func: mockUpgradeFunc1
      upgradeDB.upgradeFuncs.push
        description: 'mock func 2'
        func: mockUpgradeFunc2

      upgradeDB.upgradeDb ->
        func1Complete.should.be.exactly true
        func2Complete.should.be.exactly true
        done()

  describe 'updateFunction0 - Ensure cert fingerprint', ->

    upgradeFunc = upgradeDB.upgradeFuncs[0].func

    beforeEach (done) ->
      testUtils.setupTestKeystore ->
        Keystore.findOne (err, keystore) ->
          keystore.cert.fingerprint = undefined
          for cert in keystore.ca
            cert.fingerprint = undefined
          keystore.save (err) ->
            if err then logger.error err
            done()

    it 'should add the fingerprint property to ca certificates', (done) ->
      upgradeFunc().then ->
        Keystore.findOne (err, keystore) ->
          if err then logger.error err
          for cert in keystore.ca
            cert.fingerprint.should.exist
          done()

    it 'should add the fingerprint property to server certificate', (done) ->
      upgradeFunc().then ->
        Keystore.findOne (err, keystore) ->
          if err then logger.error err
          keystore.cert.fingerprint.should.exist
          done()

  describe 'updateFunction1 - Convert client.domain to client.fingerprint', ->

    upgradeFunc = upgradeDB.upgradeFuncs[1].func

    clientData =
      clientID: "test"
      clientDomain: "trust1.org" # in default test keystore
      name: "Test client"
      roles: [
          "OpenMRS_PoC"
          "PoC"
        ]

    before (done) ->
      testUtils.setupTestKeystore ->
        client = new Client clientData
        client.save (err) ->
          if err? then logger.error err
          done()

    it 'should convert client.domain match to client.certFingerprint match', ->
      upgradeFunc().then ->
        Client.findOne clientID: "test", (err, client) ->
          client.certFingerprint.should.be.exactly "23:1D:0B:AA:70:06:A5:D4:DC:E9:B9:C3:BD:2C:56:7F:29:D2:3E:54"

  describe 'updateFunction2 - Migrate visualizer settings from user profile to shared collection', ->

    upgradeFunc = upgradeDB.upgradeFuncs[2].func

    userObj1 =
      firstname: "Test"
      surname: "User1"
      email: "test1@user.org"
      settings:
        visualizer:
          components: [
              eventType: 'primary'
              eventName: 'OpenHIM Mediator FHIR Proxy Route'
              display: 'FHIR Server'
            ,
              eventType: 'primary'
              eventName: 'echo'
              display: 'Echo'
          ]
          color:
            inactive: '#c8cacf'
            active: '#10e057'
            error: '#a84b5c'
            text: '#4a4254'
          size:
            responsive: true
            width: 1000
            height: 400
            paddin: 20
          time:
            updatePeriod: 200
            maxSpeed: 5
            maxTimeout: 5000
            minDisplayPeriod: 500
          channels: [
              eventType: 'channel'
              eventName: 'FHIR Proxy'
              display: 'FHIR Proxy'
            ,
              eventType: 'channel'
              eventName: 'Echo'
              display: 'Echo'
          ]
          mediators: [
              mediator: 'urn:mediator:fhir-proxy'
              name: 'OpenHIM Mediator FHIR Proxy'
              display: 'OpenHIM Mediator FHIR Proxy'
            ,
              mediator: 'urn:mediator:shell-script'
              name: 'OpenHIM Shell Script Mediator'
              display: 'OpenHIM Shell Script Mediator'
          ]
    userObj2 =
      firstname: "Test"
      surname: "User2"
      email: "test2@user.org"
      settings:
        visualizer:
          components: [
              eventType: 'primary'
              eventName: 'OpenHIM Mediator FHIR Proxy Route'
              display: 'FHIR Server'
          ]
          color:
            inactive: '#c8cacf'
            active: '#10e057'
            error: '#a84b5c'
            text: '#4a4254'
          size:
            responsive: true
            width: 1000
            height: 400
            paddin: 20
          time:
            updatePeriod: 200
            maxSpeed: 5
            maxTimeout: 5000
            minDisplayPeriod: 500
          channels: [
              eventType: 'channel'
              eventName: 'FHIR Proxy'
              display: 'FHIR Proxy'
          ]
          mediators: [
              mediator: 'urn:mediator:fhir-proxy'
              name: 'OpenHIM Mediator FHIR Proxy'
              display: 'OpenHIM Mediator FHIR Proxy'
          ]
    userObj3 =
      firstname: "Test"
      surname: "User3"
      email: "test3@user.org"
      settings:
        visualizer:
          color:
            inactive: '#c8cacf'
            active: '#10e057'
            error: '#a84b5c'
            text: '#4a4254'
          size:
            responsive: true
            width: 1000
            height: 400
            paddin: 20
          time:
            updatePeriod: 200
            maxSpeed: 5
            maxTimeout: 5000
            minDisplayPeriod: 500
          components: []
          channels: []
          mediators: []

    # from structure for Console v1.6.0
    userObj4 =
      settings:
        list: {}
        visualizer:
          time:
            maxTimeout: 5000
            maxSpeed: 5
            updatePeriod: 200
          size:
            padding: 20
            height: 400
            width: 1000
            responsive: true
          color:
            text: "000000"
            error: "d43f3a"
            active: "4cae4c"
            inactive: "CCCCCC"
          endpoints: [
              desc: "Test Channel"
              event: "channel-test"
          ]
          components: [
              desc: "Test"
              event: "test"
            ,
              desc: "Test Route"
              event: "route-testroute"
          ]
        filter:
          limit: 100
      email: "test4@user.org"
      firstname: "Test"
      surname: "User4"
      groups: [
        "admin"
      ]

    # from structure for Console v1.6.0
    userObj5 =
      settings:
        list: {}
        visualizer:
          time:
            maxTimeout: 5000
            maxSpeed: 5
            updatePeriod: 200
          size:
            padding: 20
            height: 400
            width: 1000
            responsive: true
          color:
            text: "000000"
            error: "d43f3a"
            active: "4cae4c"
            inactive: "CCCCCC"
          endpoints: []
          components: []
        filter:
          limit: 100
      email: "test5@user.org"
      firstname: "Test"
      surname: "User5"
      groups: [
        "admin"
      ]


    before (done) ->
      User.remove () ->
        Visualizer.remove () ->
          done()

    beforeEach (done) ->
      user = new User userObj1
      user.save (err) ->
        user = new User userObj2
        user.save (err) ->
          if err? then return done err
          done()

    afterEach (done) ->
      User.remove () ->
        Visualizer.remove () ->
          done()

    it 'should migrate visualizer settings from user setting to shared collection', (done) ->
      upgradeFunc().then ->
        Visualizer.find (err, visualizers) ->
          if err then return done err
          visualizers.length.should.be.exactly 2
          names = visualizers.map((v) -> v.name)
          idx1 = names.indexOf("Test User1's visualizer")
          idx2 = names.indexOf("Test User2's visualizer")
          idx1.should.be.above -1
          visualizers[idx1].components.length.should.be.exactly 2
          idx2.should.be.above -1
          visualizers[idx2].components.length.should.be.exactly 1
          done()
      .catch (err) ->
        done err

    it 'should migrate visualizer settings even when user have the same name', (done) ->
      User.findOne { surname: "User2" }, (err, user) ->
        user.surname = "User1"
        user.save (err) ->
          if err then return done err
          upgradeFunc().then ->
            Visualizer.find (err, visualizers) ->
              if err then return done err
              visualizers.length.should.be.exactly 2
              names = visualizers.map((v) -> v.name)
              idx1 = names.indexOf("Test User1's visualizer")
              idx2 = names.indexOf("Test User1's visualizer 2")
              idx1.should.be.above -1
              visualizers[idx1].components.length.should.be.exactly 2
              idx2.should.be.above -1
              visualizers[idx2].components.length.should.be.exactly 1
              done()
          .catch (err) ->
            done err

    it 'should remove the users visualizer setting from their profile', (done) ->
      upgradeFunc().then ->
        User.findOne { email: "test1@user.org" }, (err, user) ->
          should.not.exist user.settings.visualizer
          done()

    it 'should ignore users that don\'t have a settings.visualizer or settings set', (done) ->
      User.find (err, users) ->
        users[0].set 'settings.visualizer', null
        users[1].set 'settings', null
        users[0].save (err) ->
          users[1].save (err) ->
            upgradeFunc().then ->
              Visualizer.find (err, visualizers) ->
                visualizers.length.should.be.exactly 0
                done()
            .catch (err) ->
              done err

    it 'should ignore users that have visualizer settings with no mediators, components or channels', (done) ->
      user = new User userObj3
      user.save (err) ->
        if err then done err
        upgradeFunc().then ->
          Visualizer.find (err, visualizers) ->
            visualizers.length.should.be.exactly 2 # third user is skipped
            done()
        .catch (err) ->
          done err

    it 'should migrate old visualizers (core 2.0.0, console 1.6.0 and earlier)', (done) ->
      user = new User userObj4
      user.save (err) ->
        if err then done err
        upgradeFunc().then ->
          Visualizer.find (err, visualizers) ->
            visualizers.length.should.be.exactly 3

            names = visualizers.map((v) -> v.name)
            idx = names.indexOf("Test User4's visualizer")

            visualizers[idx].time.minDisplayPeriod.should.be.exactly 100
            visualizers[idx].mediators.length.should.be.exactly 0

            visualizers[idx].channels.length.should.be.exactly 1
            visualizers[idx].channels[0].eventType.should.be.equal 'channel'
            visualizers[idx].channels[0].eventName.should.be.equal 'test'
            visualizers[idx].channels[0].display.should.be.equal 'Test Channel'

            visualizers[idx].components.length.should.be.exactly 2
            visualizers[idx].components[0].eventType.should.be.equal 'channel'
            visualizers[idx].components[0].eventName.should.be.equal 'test'
            visualizers[idx].components[0].display.should.be.equal 'Test'
            visualizers[idx].components[1].eventType.should.be.equal 'route'
            visualizers[idx].components[1].eventName.should.be.equal 'testroute'
            visualizers[idx].components[1].display.should.be.equal 'Test Route'
            done()
        .catch (err) ->
          done err

    it 'should ignore users that have visualizer settings with no components or endpoints (core 2.0.0, console 1.6.0 and earlier)', (done) ->
      user = new User userObj5
      user.save (err) ->
        if err then done err
        upgradeFunc().then ->
          Visualizer.find (err, visualizers) ->
            visualizers.length.should.be.exactly 2
            done()
        .catch (err) ->
          done err

  describe 'dedupName()', ->

    it 'should correctly dedup a name', ->
      names = [ "Max", "Sam", "John" ]
      name = upgradeDB.dedupName "Max", names
      name.should.be.exactly "Max 2"

    it 'should bump the increment if there are multiple dupes', ->
      names = [ "Max", "Max 2", "Max 3" ]
      name = upgradeDB.dedupName "Max", names
      name.should.be.exactly "Max 4"

    it 'should return the original name of no dupes', ->
      names = [ "Sam", "John", "Simon" ]
      name = upgradeDB.dedupName "Max", names
      name.should.be.exactly "Max"

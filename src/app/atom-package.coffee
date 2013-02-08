Package = require 'package'
fs = require 'fs'
_ = require 'underscore'
$ = require 'jquery'

module.exports =
class AtomPackage extends Package
  metadata: null
  keymapsDirPath: null

  constructor: ->
    super
    @keymapsDirPath = fs.join(@path, 'keymaps')

  load: ({activateImmediately}={}) ->
    try
      @loadMetadata()
      @loadKeymaps()
      @loadStylesheets()
      activationEvents = @getActivationEvents()
      if activationEvents and not activateImmediately
        @subscribeToActivationEvents(activationEvents)
      else
        @activatePackageMain()
    catch e
      console.warn "Failed to load package named '#{@name}'", e.stack
    this

  disableEventHandlersOnBubblePath: (event) ->
    bubblePathEventHandlers = []
    disabledHandler = ->
    element = $(event.target)
    while element.length
      if eventHandlers = element.data('events')?[event.type]
        for eventHandler in eventHandlers
          eventHandler.disabledHandler = eventHandler.handler
          eventHandler.handler = disabledHandler
          bubblePathEventHandlers.push(eventHandler)
      element = element.parent()
    bubblePathEventHandlers

  restoreEventHandlersOnBubblePath: (eventHandlers) ->
    for eventHandler in eventHandlers
      eventHandler.handler = eventHandler.disabledHandler
      delete eventHandler.disabledHandler

  unsubscribeFromActivationEvents: (activationEvents, activateHandler) ->
    if _.isArray(activationEvents)
      rootView.off(event, activateHandler) for event in activationEvents
    else
      rootView.off(event, selector, activateHandler) for event, selector of activationEvents

  subscribeToActivationEvents: (activationEvents) ->
    activateHandler = (event) =>
      bubblePathEventHandlers = @disableEventHandlersOnBubblePath(event)
      @activatePackageMain()
      $(event.target).trigger(event)
      @restoreEventHandlersOnBubblePath(bubblePathEventHandlers)
      @unsubscribeFromActivationEvents(activationEvents, activateHandler)

    if _.isArray(activationEvents)
      rootView.command(event, activateHandler) for event in activationEvents
    else
      rootView.command(event, selector, activateHandler) for event, selector of activationEvents

  activatePackageMain: ->
    mainPath = @path
    mainPath = fs.join(mainPath, @metadata.main) if @metadata.main
    mainPath = require.resolve(mainPath)
    if fs.isFile(mainPath)
      @packageMain = require(mainPath)
      rootView?.activatePackage(@name, @packageMain)

  getActivationEvents: -> @metadata.activationEvents

  loadMetadata: ->
    if metadataPath = fs.resolveExtension(fs.join(@path, 'package'), ['cson', 'json'])
      @metadata = fs.readObject(metadataPath)
    @metadata ?= {}

  loadKeymaps: ->
    if keymaps = @metadata.keymaps
      keymaps = keymaps.map (relativePath) =>
        fs.resolve(@keymapsDirPath, relativePath, ['cson', 'json', ''])
      keymap.load(keymapPath) for keymapPath in keymaps
    else
      keymap.loadDirectory(@keymapsDirPath)

  loadStylesheets: ->
    for stylesheetPath in @getStylesheetPaths()
      requireStylesheet(stylesheetPath)

  getStylesheetPaths: ->
    stylesheetDirPath = fs.join(@path, 'stylesheets')
    fs.list(stylesheetDirPath)

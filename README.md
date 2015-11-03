# Cordova-Plugin-Couchbase-Lite
Couchbase Lite Cordova plugin that provides a
full typescript and scalajs interface over CBL's REST API

API is directly inspired by the epic [PouchDB](http://pouchdb.com)

This project assumes that [URI.js](http://example.net/) is in the global namespace


## Deviations From The PouchDB API

## Quirks
When creating a new db all illegal characters( /[^a-z0-9$_()+-/]/g )
are automatically removed upon cbl instance construction.
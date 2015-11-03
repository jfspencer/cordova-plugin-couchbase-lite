# Cordova-Plugin-Couchbase-Lite
Couchbase Lite Cordova plugin that provides a
full typescript and scalajs interface over CBL's REST API

API is directly inspired by the epic [PouchDB](http://pouchdb.com)

This project assumes that [URI.js](http://example.net/) is in the global namespace


## Deviations From The PouchDB API

## Quirks Compared to Pouch API
- When creating a new db all illegal characters( /[^a-z0-9$_()+-/]/g )
in the dbName are automatically removed upon cbl instance construction.

- The only valid option for creating a new CBL instance is the name
option. Auto_compaction is not included because ForestDB will inherently
auto_compact. This Forest db will become the default engine in the near
future.

- The dbName can only be string name, not a url to a remote couchDB.
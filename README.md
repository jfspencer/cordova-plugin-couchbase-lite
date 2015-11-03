# Cordova-Plugin-Couchbase-Lite
Couchbase Lite Cordova plugin that provides a
full typescript and scalajs interface over CBL's REST API

API strictly follows [PouchDB](http://pouchdb.com/api.html)'s API,
 with the exceptions listed under [Quirks Compared to PouchAPI](#quirks)

This project assumes that [URI.js](https://medialize.github.io/URI.js/)
 and [lodash](https://lodash.com/docs) are in the global namespace of
 the implementing project.

## <a name="quirks"></a>Quirks Compared to Pouch API
- When creating a new db, all illegal characters( /[^a-z0-9$_()+-/]/g )
in the dbName are automatically removed upon cbl instance construction.

- The only valid option for creating a new CBL instance is the name
option. Auto_compaction is not included because ForestDB will inherently
auto_compact. This Forest db will become the default engine in the near
future.

- The dbName can only be string name, not a url to a remote couchDB. CBL
only provides interfaces for replicating to and from an internal database.

- The API only returns promises. Callbacks are not supported.

- An Upsert Function is provided. Automatically updates or inserts the
provided doc. If the document exists, the latest revision is applied to
 the input doc to force a successful update with the procided doc.
 WARNING: Will blindly overwrite data if an older revision doc is passed in.
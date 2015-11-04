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
This prevents dealing with illegal db name errors.

- The only valid option for creating a new CBL instance is the name
option. Auto_compaction is not included because ForestDB will inherently
auto_compact. This Forest db will become the default engine in the near
future.

- the CBL instance needs to be initialized after creation.
call cbl.initDB(). This retrieves the server url and creates the dbUrl
used by the API functions. It also attempts to create a database with
the name provided by the constructor. will only generate an error if the
response status is not 201 or 412.

- The dbName can only be string name, not a url to a remote couchDB. CBL
only provides interfaces for replicating to and from an internal database.

- The API only returns promises. Callbacks are not supported.

- when putting an attachment, the _rev is always inferred. a new doc is
created if _rev is not present. Only inline attachments are supported.

- The remove function only supports remove(doc:Object, params). A rev
defined in the params takes precedence over the doc._rev.

- An Upsert Function is provided. It automatically updates or inserts the
provided doc. If the document exists, the latest revision is applied to
 the input doc to force a successful update with the provided doc.
 WARNING: Will blindly overwrite data if an older revision id is passed in.

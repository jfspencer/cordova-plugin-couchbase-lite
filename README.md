# Cordova-Plugin-Couchbase-Lite
Couchbase Lite Cordova plugin that provides a
full typescript and scalajs interface over CBL's REST API

API strictly follows [PouchDB](http://pouchdb.com/api.html)'s API,
 with the exceptions listed under [Differences Compared to PouchAPI](#quirks)

This project depends on
[URI.js](https://medialize.github.io/URI.js/),[lodash](https://lodash.com/docs) and an
[A+ compliant library](https://github.com/promises-aplus/promises-spec/blob/master/implementations.md)
  to be globally available in the implementing project.

## Brief API Overview
note: The typescript API is formatted for use with external module systems.

Create a New CBL API Instance

    new CBL(dbName)

initDB: Initialize the instance. Creates a new DB or obtains the db url for
an existing DB.

    initDB():Promise

allDocs: Fetch multiple docs by indexed by _id. See
[Pouch allDocs](http://pouchdb.com/api.html#batch_fetch), no API differences

    allDocs(params:Object):Promise

bulkDocs: Create multiple docs at once. See
[Pouch bulkDocs](http://pouchdb.com/api.html#batch_create), no API differences

    bulkDocs(docs:Array<Objects>):Promise

changes: Subscribe to database change events. See
[Pouch changes](http://pouchdb.com/api.html#changes), no API differences

    changes(params:Objects):Object(Event Emitter)

compact: Reduce db file size by removing outdated leaf revisions. This function creates an
optimized duplicate database. Therefore up to twice the current storage space of the
 specified database is required for the compaction routine to complete.
[Pouch compact](http://pouchdb.com/api.html#compaction), no API differences

    compact():Promise

destroy: deletes the database. See
[Pouch destroy](http://pouchdb.com/api.html#delete_database), no API differences

    destroy():Promise

get: Get a single doc from the db. See
[Pouch get](http://pouchdb.com/api.html#fetch_document), no API differences

    get(docId:string, params?:Object):Promise

getAttachment: Get an attachment associated with a doc. See
[Pouch getAttachment](http://pouchdb.com/api.html#bget_attachment), no API differences

    getAttachment(docId:string, attachmentName:string, params?:Object):Promise

info: Get basic info about the db including, name, # of docs and current seq id. See
[Pouch info](http://pouchdb.com/api.html#database_information), no API differences

    info():Promise

post: Creates a doc in the DB. The DB will create the id for you if _id is not specified.
Use PUT if you are updating a doc.
 See [Pouch post](http://pouchdb.com/api.html#using-dbpost), no API differences

    post(docs:Object, params?:Object):Promise

put: Create or update a doc in the DB. Must have user generated _id. See
[Pouch put](http://pouchdb.com/api.html#create_document), DIFFERENCES: docId and revId
are always inferred from the input doc, if rev is provided in the params, it takes
precedence over the doc._rev;

    put(doc:Object, params?:Object):Promise

putAttachment: add an attachment. See
[Pouch putAttachment](http://pouchdb.com/api.html#save_attachment), DIFFERENCE: rev is
the last param in the signature.

    putAttachment(docId:string, attachmentId:string, attachment:any, mimeType:string, rev?:string):Promise

query: perform a view lookup based on the index of a design document. See
[Pouch query](http://pouchdb.com/api.html#query_database), no API differences

    query(view:string, params:Object):Promise

replicate.to: Start replication to a remote DB from a cbl DB. See
[Pouch replicate.to](http://pouchdb.com/api.html#example-usage-9), no API differences

    replicate.to(remoteDbUrl:string):Object(event emitter)

replicate.from: Start replication from a remote DB to a cbl DB. See
[Pouch replicate.from](http://pouchdb.com/api.html#example-usage-9), no API differences

    replicate.from(remoteDbUrl:string):Object(event emitter)

remove: delete a document. See
[Pouch remove](http://pouchdb.com/api.html#delete_document), no API differences

    remove(doc:Object, params?:Object):Promise

removeAttachment: Remove an attachment from a specified doc. See
[Pouch removeAttachment](http://pouchdb.com/api.html#delete_attachment),
 no API differences

    removeAttachment(docId:string, attachmentId:string, rev:string):Promise

revDiffs: NOT IMPLEMENTED YET : Provided a list of rev ids for a given doc, 
returns a subset of rev ids not stored in the db for that doc. See
[Pouch revDiffs](http://pouchdb.com/api.html#revisions_diff)

    revsDiff(doc:Object):Promise

upsert: Automatically updates or inserts the provided doc.
WARNING: Will blindly overwrite data if an older revision id is passed in.This
is a convenience function. It is similar to
[Nolan Lawson's Upsert](https://github.com/pouchdb/upsert) But not as robust.

    upsert(doc:Object, params?:Object):Promise

viewCleanup: NOT IMPLEMENTED YET Removes indexes that do not have a companion design doc and updates stale view
indexes. See[Pouch bulkDocs](http://pouchdb.com/api.html#view_cleanup),


    viewCleanup():Promise


## <a name="quirks"></a>Summary of Differences Compared to Pouch API
- When creating a new db, all illegal characters( /[^a-z0-9$_()+-/]/g )
in the dbName are automatically removed upon cbl instance construction.
This prevents dealing with illegal db name errors.

- The only valid option for creating a new CBL instance is the name
option. Auto_compaction is not included because ForestDB will inherently
auto_compact. This Forest db will become the default engine in the near
future.

- the CBL instance needs to be initialized after creation.
call initDB() on the new instance. This retrieves the server url and
creates the dbUrl used by the API functions. It also attempts to create
a database with the name provided by the constructor. Will only
generate an error if the response status is not 201 or 412.

- The dbName can only be string name, not a url to a remote couchDB. CBL
only provides interfaces for replicating to and from an internal database.

- The API only returns promises or in the case of changes and replication
an object. Callbacks are not supported.

- The remove function only supports remove(doc:Object, params). A rev
defined in the params takes precedence over the doc._rev.

- The replicate and sync functions are not provided because there is not a
 static object for CBL to work from. Use replicate.to or replicate.from on
 a CBL instance instead.

- An Upsert Function is provided. It automatically updates or inserts the
provided doc. If the document exists, the latest revision is applied to
 the input doc to force a successful update with the provided doc.
 WARNING: Will blindly overwrite data if an older revision id is passed in.

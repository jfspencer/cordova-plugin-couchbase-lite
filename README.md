# Cordova-Plugin-Couchbase-Lite
Couchbase Lite Cordova plugin that provides a full typescript and scalajs interfaces over
 CBL's REST API. This repo is intentionally not forked from the main
[couchbase-lite-phonegap](https://github.com/couchbaselabs/Couchbase-Lite-PhoneGap-Plugin)
repo. A seperate issue tracker is needed to track issues and progress with the typescript and
scalajs interface code. This repo does not intend to provide improvements ahead of the main
 repository for the native code. This code will be manually updated as it is
 released from couchbase.

API follows [PouchDB](http://pouchdb.com/api.html)'s API as strictly as possible,
 with the exceptions listed under [Differences Compared to PouchAPI](#quirks).
 If you have a suggestion on how to remove an exception(s) please submit a pull request.

This project depends on
[URI.js](https://medialize.github.io/URI.js/), [lodash](https://lodash.com/docs) and an
[A+ compliant library](https://github.com/promises-aplus/promises-spec/blob/master/implementations.md)
  to be globally available in the implementing project.

## Cordova Setup
- Add the util/010_addxcodeoptions.js to the hooks/after_prepare folder. This file turns off
bit code and slicing. The CBL iOS libraries do not support them yet. Also has commented config
options for supporting swift in cordova ios projects.

## TypeScript Installation
- here is a reference implementation of typescript cordova/ionic and cbl [TypeApp](https://github.com/happieio/typeapp)

- First add the plugin to your project by

    cordova add plugin https://github.com/happieio/cordova-plugin-couchbase-lite.git

- Second move the following API files into the appropriate place in your project.
  - APIs -> typescript -> cbl.ts & cblemitter.ts
  - APIs -> typescript -> typedefs -> cbl.d.ts & cblemitter.d.ts & cblsubtypes.d.ts & eventsource.d.ts

- Third Fix the /// reference paths to be relative to your project and link to or copy the
bluebird, jquery, lodash and urijs definition files.

- Fourth import the cbl.ts file into your data access class and have fun :)

## ScalaJS Installation - API NOT WRITTEN YET
First add the plugin to your project by

    cordova add plugin https://github.com/happieio/cordova-plugin-couchbase-lite.git


## Contributing
Your Help in writing unit tests for Travis are very welcome and reporting or generating
a pull request for bug fixes or improvements are always welcome too!


## Brief API Overview
note: The typescript API is formatted for use with external module systems(AMD, CommonJS etc.).

Create a New CBL API Instance

    new CBL(dbName)

initDB: Initialize the instance. Creates a new DB or obtains the db url for
an existing DB. Passing in a remote couch db will initialize the remote db
as the primary db. This currently requres the user:pass@url syntax. have not implemented
cookie authentication.

    initDB(remoteDBUrl?):Promise

allDocs: Fetch multiple docs from the primary _id index. See
[Pouch allDocs](http://pouchdb.com/api.html#batch_fetch), no API differences

    allDocs(params:Object):Promise

bulkDocs: Create multiple docs at once. See
[Pouch bulkDocs](http://pouchdb.com/api.html#batch_create), no API differences

    bulkDocs(docs:Array<Objects>):Promise

changes: Subscribe to database change events. See
[Pouch changes](http://pouchdb.com/api.html#changes),
DIFFERENCES: only EventSource changes are supported. Only style is supported under advanced options.
only returns a promise in order to support the since:'now' feature.

    changes(params:Objects):Promise<Emitter>

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

replicateTo: Start replication to another DB from a cbl DB. See
[Pouch replicate.to](http://pouchdb.com/api.html#example-usage-9),
DIFFERENCES: only accepts string names/URLs. This is a single function call no sub object "to".

    replicateTo(remoteDbUrl:string, params:Object):Object(event emitter) | Promise

replicateFrom: Start replication from another DB to a cbl DB. See
[Pouch replicate.from](http://pouchdb.com/api.html#example-usage-9),
DIFFERENCES: only accepts string names/URLs. This is a single function call no sub object "from".

    replicateFrom(remoteDbUrl:string, params:Object):Object(event emitter) | Promise

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
Use replication.to or replication.from to link a local db to a remote one.

- The API only returns promises or in the case of the replication functions
an object. Callbacks are not supported.

- The remove function only supports remove(doc:Object, params). A rev
defined in the params takes precedence over the doc._rev.

- The replicate and sync functions are not provided because there is not a
 static object for CBL to work from. If you want to work from a remote db
 pass in the authenticated CouchDB url as first parameter to initDB.
  Otherwise use replicateTo or replicateFrom on a CBL instance instead.
  the replicate functions only accept string name(local)/url(remote).

- An Upsert Function is provided. It automatically updates or inserts the
provided doc. If the document exists, the latest revision is applied to
 the input doc to force a successful update with the provided doc.
 WARNING: Will blindly overwrite data if an older revision id is passed in.

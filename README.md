# Cordova-Plugin-Couchbase-Lite
Couchbase Lite Cordova plugin that provides a standard cordova interface instead of relying on the 
 built in REST Server or another HTTP API layer. The native implementations run on their own
 background thread(iOS)/threads(android) so operations will never block the UI.
 This repo is intentionally not forked from the main
[couchbase-lite-phonegap](https://github.com/couchbaselabs/Couchbase-Lite-PhoneGap-Plugin)
repo. A seperate issue tracker is needed to track issues and progress with the cordova interface
 code. This repo does not intend to provide improvements ahead of the main
 repository for the native code. This code will be manually updated as it is
 released from couchbase.
 
 The native API was developed partially out of performance concerns with the REST server and
 also in preparation for Couchbase Lite 2.

This project depends on
[RxJS 5.x](https://medialize.github.io/URI.js/), [lodash](https://lodash.com/docs) and an
[A+ compliant Promise library](https://github.com/promises-aplus/promises-spec/blob/master/implementations.md)
  to be globally available in the implementing project.

## Cordova Setup
- Add the util/010_addxcodeoptions.js to the hooks/after_prepare folder. This file turns off
bit code and slicing. The CBL iOS libraries do not support them yet. Also has commented config
options for supporting swift in cordova ios projects.

## Standard Installation
First add the plugin to your project by

    cordova add plugin https://github.com/happieio/cordova-plugin-couchbase-lite.git

## Contributing
Your Help in writing unit tests for Travis are very welcome and reporting or generating
a pull request for bug fixes or improvements are always welcome too!


## Brief API Overview
### initDb()
Params: [dbId:string]

Returns: Promise -> string

The native code maintains an array of active database instances to interact with. to create/add
and active db instance. databases are created using forestDB. 

    cbl.initDb(['dbId']).then((success:string)=> ... do stuff);

### info
Params: [dbId:string]

Returns: Promise -> number

gets the doc count of a local database
    
    cbl.info(['dbId']).then((count:number)=> ... do stuff)
    
### sync
Params: [dbId:string, syncUrl:string, user:string, pass:string]

Returns: Promise -> boolean

starts continuous push and pull replication against a database.
    
    cbl.sync(['dbId','url','user','pass']).then((isStarted:boolean)=> ... do stuff)
    
### compact
Params: [dbId:string]

Returns: Promise -> string

runs database compaction
    
    cbl.compact(['dbId']).then((success:string)=> ... do stuff)
    
### changesDatabase
Params: [dbId:string]

Returns: Observable -> {docId:string, is_delete:bool, seq_num:number}

starts a never ending (until reset is called) stream of database changes
    
    const change_sub = cbl.changesDatabase(['dbId']).subscribe((change)=> ...do stuff)
        ... later, when done
        change_sub.unsubscribe()
    
### changesReplication
Params: [dbId:string]

Returns: Observable -> 'string status'

starts a never ending (until reset is called) stream of replication changes
    
    const change_sub = cbl.changesReplication(['dbId']).subscribe((change)=> ...do stuff)
    ... later, when done
    change_sub.unsubscribe()
    
### lastSequence
Params: [dbId:string]

Returns: Promise -> number

gets the current sequence number of the given database
    
    cbl.lastSequence(['dbId']).then((seq:number)=> ... do stuff)
    
### replicateFrom
Params: [dbId:string, syncUrl:string, user:string, pass:string]

Returns: Promise -> boolean

:NOT IMPLEMENTED YET: starts a one shot replication receiving data from another database. 
resolves when replication is complete.
    
    cbl.replicateFrom(['dbId']).then((finished:boolean)=> ... do stuff)
    
### replicateTo
Params: [dbId:string, syncUrl:string, user:string, pass:string]

Returns: Promise -> boolean

:NOT IMPLEMENTED YET: starts a one shot replication sending data to another database. 
resolves when replication is complete.
    
    cbl.replicateTo(['dbId']).then((finished:boolean)=> ... do stuff)
    
### reset
Params: []

Returns: Promise -> boolean

removes all the database instances from the native array, cancels all change listeners 
on databases and replications.
    
    cbl.reset(['dbId']).then((finished:boolean)=> ... do stuff)
    
### stopReplication
Params: []

Returns: Promise -> boolean

stops all replications 
    
    cbl.stopReplication(['dbId']).then((stopped:boolean)=> ... do stuff)
    
### allDocs
Params: [dbId:string]

Returns: Observable -> [docs...]

returns all documents in the database in array batches. batch sizes have been optimized 
for each platform. this observable calls complete when finished.
    
    cbl.allDocs(['dbId']).subscribe((docBatch:[docs...])=> ...do stuff)
    
### get
Params: [dbId:string, docId:string]

Returns: Promise -> Doc

get a document from the database
    
    cbl.get(['dbId','docId']).then((doc:any)=> ...do stuff)
    
### getDocRev
Params: [dbId:string, docId:string]

Returns: Promise -> string

gets the current revision of a document
    
    cbl.getDocRev(['dbId','dicId']).then((revId:string)=> ... do stuff)
    
### putAttachment
Params: [dbId:string, docId:string, fileName:string, attachmentName:string, mimeType:string, dirPath:string ]

Returns: Promise -> number

adds an attachment to a document. the directory path of the file is relative to the 
files folder on android or the root of the app sandbox on ios.
    
    cbl.putAttachment(['dbId','docId','file', 'attachName','mime', 'dirPath']).then(... done)
    
### upsert
Params: [dbId:string, docId:string, jsonString:string, isLocal:string ("local" || "normal")]

Returns: Promise -> string

create or update a document. always makes itself the winning revision.
    
    cbl.upsert(['dbId', docId, '{\"test\":123}', false]).then(... done)
    
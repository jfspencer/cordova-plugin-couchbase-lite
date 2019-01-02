var exec = require('cordova/exec');

//////////_______UTIL_______\\\\\\\\\\
module.exports.changesDatabase = (res, err, options) => exec(res, err, "CBLite", "changesDatabase", options);
module.exports.changesReplication = (res, err, options) => exec(res, err, "CBLite", "changesReplication", options);
module.exports.compact = (res, err, options) => exec(res, err, "CBLite", "compact", options);
module.exports.resetCallbacks = (res, err) => exec(res, err, "CBLite", "resetCallbacks", []);
module.exports.info = (res, err, options) => exec(res, err, "CBLite", "info", options);
module.exports.initCallerID = (res, err, options) => exec(res, err, "CBLite", "initCallerID", options) ;
module.exports.initDb = (res, err, options) => exec(res, err, "CBLite", "initDb", options);
module.exports.startPushReplication = (res, err, options) => exec(res, err, "CBLite", "startPushReplication", options);
module.exports.pushReplicationIsRunning = (res, err) => exec(res, err, "CBLite", "pushReplicationIsRunning");
module.exports.lastSequence = (res, err, options) => exec(res, err, "CBLite", "lastSequence", options);
module.exports.replicateFrom = (res, err, options) => exec(res, err, "CBLite", "replicateFrom", options);
module.exports.replicateTo = (res, err, options) => exec(res, err, "CBLite", "replicateTo", options);
module.exports.reset = (res, err) => exec(res, err, "CBLite", "reset", null);
module.exports.stopReplication = (res, err, options) => exec(res,err, "CBLite", "stopReplication", options);
module.exports.sync = (res, err, options) => exec(res,err, "CBLite", "sync", options);

//////////_______READ_______\\\\\\\\\\
module.exports.buildViewDocs = (res, err, options) => exec(res, err, "CBLite", "buildViewDocs", options);
module.exports.viewDocs = (res, err, options) => exec(res, err, "CBLite", "viewDocs", options);
module.exports.allDocs = (res, err, options) => exec(res, err, "CBLite", "allDocs", options);
module.exports.get = (res, err, options) => exec(res, err, "CBLite", "get", options);
module.exports.getDocRev = (res, err, options) => exec(res, err, "CBLite", "getDocRev", options);

//////////_______WRITE_______\\\\\\\\\\
module.exports.deleteLocal = (res, err, options) => exec(res, err, "CBLite", "deleteLocal", options);
module.exports.putAttachment = (res, err, options) => exec(res, err, "CBLite", "putAttachment", options);
module.exports.attachmentCount = (res, err, options) => exec(res, err, "CBLite", "attachmentCount", options);

//creates or updates a document requires a doc id to present, input data will always be written as winning revision
module.exports.upsert = (res, err, options) => exec(res, err, "CBLite", "upsert", options);

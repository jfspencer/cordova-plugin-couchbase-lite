var exec = require('cordova/exec');

/**
 * Original API
 */
//////////_______UTIL_______\\\\\\\\\\
/**
 * @param options:[dbName]
 * @returns docId:Rx<{id:string, is_delete:boolean}>
 */
module.exports.changesDatabase$ = function changesDatabase$(options) {
    return Rx.Observable.create(function cblChangesSubscribe(observer) {
        exec(function (res) {
                try{
                    observer.next(eval("(" + res + ")"));
                }
                catch(e){
                    observer.error(e);
                }
            },
            function (err) {
                observer.error(err);
            }, "CBLite", "changesDatabase", options);
    });
};

/**
 * @param options:[dbName]
 * @returns ReplicationStatus:Rx<{status:string, message:string}>
 */
module.exports.changesReplication$ = function changesReplication$(options) {
    return Rx.Observable.create(function cblReplicationSubscribe(observer) {
        exec(function (res) {
                try{
                    observer.next(eval("(" + res + ")"));
                }
                catch(e){
                    observer.error(e);
                }
            },
            function (err) {
                observer.error(err);
            }, "CBLite", "changesReplication", options);
    });
};

/**
 * @param options:[dbName]
 * @returns message:string
 */
module.exports.compact = function compact(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "compact", options);
    });
};

/**
 * @returns message:string
 */
module.exports.resetCallbacks = function compact() {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "resetCallbacks", []);
    });
};

/**
 * @param options:[dbName]
 * @returns docCount:Number
 */
module.exports.info = function info(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "info", options);
    });
};

/**
 * @param options:[dbName]
 * @returns message:string
 */
module.exports.initDb = function initDb(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "initDb", options);
    });
};

/**
 * @param options:[dbName]
 * @returns sequenceNumber:number
 */
module.exports.lastSequence = function lastSequence(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "lastSequence", options);
    });
};

/**
 * One off inbound replication
 * @param options:[dbName]
 * @returns message:string
 */
module.exports.replicateFrom = function replicateFrom(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "replicateFrom", options);
    });
};

/**
 * One off outbound replication
 * @param options:[dbName]
 * @returns message:string
 */
module.exports.replicateTo = function replicateTo(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "replicateTo", options);
    });
};

/**
 * destroys all instance data(db's, manangers etc) effectively returning cbl to clean state for initialization
 * @param none
 * @returns void
 */
module.exports.reset = function reset() {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "reset", null);
    });
};

/**
 * @param options:[dbName]
 * @returns message:string
 */
module.exports.stopReplication = function stopReplication(options) {
    return new Promise(function (resolve, reject) {
        exec(function (url) {resolve(url);}, function (err) {reject(err);}, "CBLite", "stopReplication", options);
    });

};

/**
 * Continuous Two way replication
 * @param options:[dbName:string, syncUrl:string, user:string, pass:string]
 * @returns message:string
 */
module.exports.sync = function sync(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "sync", options);
    })
};

//////////_______READ_______\\\\\\\\\\
/**
 * @param options:[dbName]
 * @returns allDocs:Rx<[docs...]>
 */
module.exports.allDocs$ = function allDocs$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                if (_.isEmpty(res)) subscriber.complete();
                else subscriber.next(eval("(" + res + ")"));
            },
            function (err) {subscriber.error(err);}, "CBLite", "allDocs", options);
    });
};

/**
 * @param options:[dbName:string, docId:string, isLocal:string<true || false>]
 * @returns JSON:Object
 */
module.exports.get = function get(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(eval("(" + res + ")"));}, function (err) {reject(err);}, "CBLite", "get", options);
    });
};

/**
 * @param options:[dbName:string, docId:string]
 * @returns RevisionId:String
 */
module.exports.getDocRev = function getDocRev(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "getDocRev", options);
    });
};

//////////_______WRITE_______\\\\\\\\\\
//create a document with an auto generated id
/**
 * @param options:[dbName, docId, fileName, name, mime, dirName]
 * @returns message:string
 */
module.exports.putAttachment = function putAttachment(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "putAttachment", options);
    });
};

//creates or updates a document requires a doc id to present, input data will always be written as winning revision
/**
 * @param options:[dbName:string, docId:string, jsonString:string, isLocal:boolean]
 * @returns message:string
 */
module.exports.upsert = function upsert(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "upsert", options);
    });
};
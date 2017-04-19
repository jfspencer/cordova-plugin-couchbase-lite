var exec = require('cordova/exec');

/**
 * Original API
 */
//////////_______UTIL_______\\\\\\\\\\
/**
 * @param options:[dbName]
 * @returns docId:Rx
 */
module.exports.changesDatabase$ = function changes$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
            },
            function (err) {subscriber.error(err);}, "CBLite", "changesDatabase", options);
    });
};

/**
 * @param options:[dbName]
 * @returns docId:Rx
 */
module.exports.changesReplication$ = function changes$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
            },
            function (err) {subscriber.error(err);}, "CBLite", "changesReplication", options);
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
 * @returns JSON:Rx
 */
module.exports.allDocs$ = function allDocs$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                if (_.isEmpty(res)) subscriber.complete();
                else {
                    var data = eval("(" + res + ")");
                    if (data.doc) subscriber.next(data.doc);
                    else subscriber.next(data);
                }
            },
            function (err) {subscriber.error(err);}, "CBLite", "allDocs", options);
    });
};

/**
 * @param options:[dbName]
 * @returns JSON:Object
 */
module.exports.get = function get(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(eval("(" + res + ")"));}, function (err) {reject(err);}, "CBLite", "get", options);
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
 * @param options:[dbName:string, docId:string, jsonString:string]
 * @returns message:string
 */
module.exports.upsert = function upsert(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "upsert", options);
    });
};
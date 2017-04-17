var exec = require('cordova/exec');

/**
 * Original API
 */
//////////_______UTIL_______\\\\\\\\\\
module.exports.changes$ = function changes$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBLite", "changes", options);
    });
};

module.exports.compact = function compact(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "compact", options);
    });
};

module.exports.info = function info(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "info", options);
    });
};

module.exports.initDb = function initDb(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "initDb", options);
    });
};

//One off inbound replication
module.exports.replicateFrom = function replicateFrom(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "replicateFrom", options);
    });
};

//One off outbound replication
module.exports.replicateTo = function replicateTo(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "replicateTo", options);
    });
};

//destroys all instance data(db's, manangers etc) effectively returning cbl to clean state for initialization
module.exports.reset = function reset(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "reset", options);
    });
};

module.exports.stopReplication = function stopReplication(options) {
    return new Promise(function (resolve, reject) {
        exec(function (url) {resolve(url);}, function (err) {reject(err);}, "CBLite", "stopReplication", options);
    });

};

//Continuous Two way replication
module.exports.sync = function dbSync(options) {
    return new Promise(function(resolve, reject){
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "sync", options);
    })
};

//////////_______READ_______\\\\\\\\\\
module.exports.allDocs$ = function allDocs$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                res.forEach(function (item) {subscriber.next(item);});
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBLite", "allDocs", options);
    });
};

module.exports.get = function get(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "get", options);
    });
};

//////////_______WRITE_______\\\\\\\\\\
//create a document with an auto generated id
module.exports.putAttachment = function putAttachment(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "putAttachment", options);
    });
};

//creates or updates a document requires a doc id to present, input data will always be written as winning revision
module.exports.upsert = function upsert(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBLite", "upsert", options);
    });
};
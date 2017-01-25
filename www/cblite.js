var exec = require('cordova/exec');

/**
 * Original API
 */

module.exports.getServerURL = function getServerURL(success, failure) {
    exec(function (url) {success(url);}, function (err) {failure(err);}, "CBLite", "getURL", []);
};

module.exports.isReplicating = function isReplicating(dbName, success, failure) {
    exec(function (url) {success(url);}, function (err) {failure(err);}, "CBLite", "isReplicating", [dbName]);
};

module.exports.closeManager = function closeManager(success, failure) {
    exec(function (url) {success(url);}, function (err) {failure(err);}, "CBLite", "closeManager", []);
};

module.exports.relaunchManager = function relaunchManager(success, failure) {
    exec(function (url) {success(url);}, function (err) {failure(err);}, "CBLite", "relaunchManager", []);
};

module.exports.stopReplication = function stopReplication(dbName, success, failure) {
    exec(function (url) {success(url);}, function (err) {failure(err);}, "CBLite", "stopReplication", [dbName]);
};

module.exports.putAttachment = function putAttachment(success, failure, options) {
    exec(function (res) {success(res);}, function (err) {failure(err);}, "CBLite", "putAttachment", options);
};

module.exports.dbSync = function dbSync(success, failure, options) {
    exec(function (res) {success(res);}, function (err) {failure(err);}, "CBLite", "dbSync", options);
};

/**
 * Promise API
 */

//////////_______UTIL_______\\\\\\\\\\
module.exports.activeTasks = function activeTasks(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "activeTasks", options)
    });
};

module.exports.changes = function changes(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "changes", options)
    });
};

module.exports.compact = function compact(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "compact", options)
    });
};

module.exports.destroy = function destroy(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "destroy", options)
    });
};

module.exports.info = function info(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "info", options)
    });
};

module.exports.initDb = function initDb(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "initDb", options)
    });
};

module.exports.replicateFrom = function replicateFrom(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "replicateFrom", options)
    });
};

module.exports.replicateTo = function replicateTo(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "replicateTo", options)
    });
};

//destroys all instance data(db's, manangers etc) effectively returning cbl to clean state for initialization
module.exports.reset = function reset(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "reset", options)
    });
};

module.exports.revsDiff = function revsDiff(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "revsDiff", options)
    });
};

module.exports.viewCleanup = function viewCleanup(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "viewCleanup", options)
    });
};

//////////_______READ_______\\\\\\\\\\
module.exports.allDocs = function allDocs(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "allDocs", options)
    });
};

module.exports.get = function get(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "get", options)
    });
};

module.exports.getAttachment = function getAttachment(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "getAttachment", options)
    });
};

module.exports.query = function query(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "query", options)
    });
};

//////////_______WRITE_______\\\\\\\\\\
module.exports.bulkDocs = function bulkDocs(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "bulkDocs", options)
    });
};

module.exports.post = function post(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "post", options)
    });
};

//
module.exports.put = function put(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "put", options)
    });
};

module.exports.putAttachmentNew = function putAttachment(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "putAttachment", options)
    });
};

module.exports.remove = function remove(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "remove", options)
    });
};

module.exports.removeAttachment = function removeAttachment(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "removeAttachment", options)
    });
};

module.exports.upsert = function upsert(options) {
    return new Promise(function (resolve, reject) {
        exec(function (res) {resolve(res);}, function (err) {reject(err);}, "CBlite", "upsert", options)
    });
};


/**
 * Rx API
 */
//////////_______UTIL_______\\\\\\\\\\
module.exports.activeTasks$ = function activeTasks$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "activeTasks", options)
    });
};

module.exports.changes$ = function changes$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "changes", options)
    });
};

module.exports.compact$ = function compact$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "compact", options)
    });
};

module.exports.destroy$ = function destroy$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "destroy", options)
    });
};

module.exports.info$ = function info$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "info", options)
    });
};

module.exports.initDb$ = function initDb$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "initDb", options)
    });
};

module.exports.replicateFrom$ = function replicateFrom$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "replicateFrom", options)
    });
};

module.exports.replicateTo$ = function replicateTo$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "replicateTo", options)
    });
};

//destroys all instance data(db's manangers etc) effectively returning cbl to clean state for initialization
module.exports.reset$ = function reset$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "reset", options)
    });
};

module.exports.revsDiff$ = function revsDiff$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "revsDiff", options)
    });
};

module.exports.viewCleanup$ = function viewCleanup$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "activeTasks", options)
    });
};

//////////_______READ_______\\\\\\\\\\
module.exports.allDocs$ = function allDocs$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                res.forEach(function (item) {subscriber.next(item);});
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "allDocs", options)
    });
};

module.exports.get$ = function get$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "get", options)
    });
};

module.exports.getAttachment$ = function getAttachment$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "getAttachment", options)
    });
};

module.exports.query$ = function query$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                res.forEach(function (item) {subscriber.next(item);});
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "query", options)
    });
};

//////////_______WRITE_______\\\\\\\\\\
module.exports.bulkDocs$ = function bulkDocs$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "bulkDocs", options)
    });
};

module.exports.post$ = function post$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "post$", options)
    });
};

module.exports.put$ = function put$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "put", options)
    });
};

module.exports.putAttachment$ = function putAttachment$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "putAttachment", options)
    });
};

module.exports.remove$ = function remove$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "remove", options)
    });
};

module.exports.removeAttachment$ = function removeAttachment$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "removeAttachment", options)
    });
};

module.exports.upsert$ = function upsert$(options) {
    return Rx.Observable.create(function (subscriber) {
        exec(function (res) {
                subscriber.next(res);
                subscriber.complete();
            },
            function (err) {subscriber.error(err);}, "CBlite", "upsert", options)
    });
};
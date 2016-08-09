function getServerURL(success, failure) {
    cordova.exec(
        function (url) {
            success(url);
        }, function (err) {
            failure(err);
        }, "CBLite", "getURL", []);
}

function close(success, failure) {
    cordova.exec(
        function (url) {
            success(url);
        },
        function (err) {
            failure(err);
        },
        "CBLite",
        "close",
        []);
}

function launchCouchbaseLite(success, failure) {
    cordova.exec(
        function (url) {
            success(url);
        },
        function (err) {
            failure(err);
        },
        "CBLite",
        "launchCouchbaseLite",
        []);
}

function stopReplication(dbName, success, failure) {
    cordova.exec(
        function (url) {
            success(url);
        },
        function (err) {
            failure(err);
        },
        "CBLite",
        "stopReplication",
        [dbName]);
}

module.exports = {
    getServerURL: getServerURL,
    stopReplication: stopReplication,
    launchCouchbaseLite:launchCouchbaseLite,
    close:close
};
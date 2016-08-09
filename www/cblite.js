function getServerURL(success, failure) {
    cordova.exec(
        function (url) {
            success(url);
        }, function (err) {
            failure(err);
        }, "CBLite", "getURL", []);
}

function closeManager(success, failure) {
    cordova.exec(
        function (url) {
            success(url);
        },
        function (err) {
            failure(err);
        },
        "CBLite",
        "closeManager",
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
    closeManager:closeManager
};
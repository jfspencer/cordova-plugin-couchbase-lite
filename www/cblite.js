function getServerURL(success, failure) {
    cordova.exec(function(url){success(url); }, function(err) { failure(err); }, "CBLite", "getURL", []);
}

module.exports = {
    getServerURL:getServerURL
};

///<reference path="cbl.d.ts" />
define(["require", "exports", 'emitter'], function (require, exports, Emitter) {
    var cblDB = (function () {
        function cblDB(dbName) {
            this.serverUrl = '';
            this.dbName = '';
            this.dbUrl = null;
            this.replicate = null;
            this.dbName = dbName;
            this.replicate = {
                from: this.replicateFrom,
                to: this.replicateTo
            };
        }
        cblDB.prototype.initDB = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                //get cbl server url
                cbl.getServerURL(function (url) {
                    _this.serverUrl = url;
                    _this.dbUrl = new URI(_this.serverUrl);
                    _this.dbUrl.directory(_this.dbName);
                    _this.processRequest('PUT', _this.dbName, null, null, function (err, response) {
                        if (err)
                            reject(err);
                        else if (response.ok)
                            resolve(true);
                        else if (response.status = 412)
                            resolve(true);
                        else
                            reject(response);
                    });
                }, function (err) { throw new Error(err); });
            });
        };
        cblDB.prototype.bulkDocs = function (docs) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Content-Type': 'application/json' };
                var uri = _this.dbUrl.directory('_bulk_docs');
                _this.processRequest('POST', uri.toString(), docs, headers, function (err, success) { if (err)
                    reject(err);
                else
                    resolve(success); });
            });
        };
        cblDB.prototype.changes = function () {
            var http = new XMLHttpRequest();
            var emitter = new Emitter();
            var uri = this.dbUrl.directory('_changes');
            http.onreadystatechange = function () {
                //if (http.readyState == 4 && http.status == 200) change(false, JSON.parse(http.responseText));
                //else error({status: http.status, response: http.responseText});
            };
            //http.open(verb, uri.toString(), true);
            //if (verb === 'GET' || verb === 'DELETE')http.send();
            //else if (verb === 'POST' || verb === 'PUT')http.send(JSON.stringify(data));
            return emitter;
        };
        cblDB.prototype.destroy = function () {
            return new Promise(function (resolve, reject) {
            });
        };
        cblDB.prototype.get = function (docId, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Content-Type': 'application/json' };
                var uri = _this.dbUrl.directory(docId);
                var requestParams = {};
                if (params)
                    requestParams = _.assign(requestParams, params);
                _this.processRequest('GET', uri.toString(), null, headers, function (err, doc) { if (err)
                    reject(err);
                else
                    resolve(doc); });
            });
        };
        cblDB.prototype.info = function () {
            return new Promise(function (resolve, reject) {
            });
        };
        cblDB.prototype.query = function (view, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var verb = 'GET';
                var headers = { 'Content-Type': 'application/json' };
                var viewParts = view.split('/');
                var uri = _this.dbUrl.directory('_design').directory(viewParts[0]).directory('_view').directory(viewParts[1]);
                var requestParams = {};
                if (params.keys) {
                    verb = 'POST';
                    requestParams.keys = params.keys;
                }
                else
                    requestParams = _.assign(requestParams, params);
                uri.search(requestParams);
                _this.processRequest(verb, uri.toString(), null, headers, function (err, response) { if (err)
                    reject(err);
                else
                    resolve(response); });
            });
        };
        cblDB.prototype.replicateFrom = function () {
        };
        cblDB.prototype.replicateTo = function () {
        };
        cblDB.prototype.upsert = function (doc, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Content-Type': 'application/json' };
                var uri = _this.dbUrl.directory(doc._id);
                var requestParams = {};
                if (params)
                    requestParams = _.assign(requestParams, params);
                if (doc._rev) {
                    requestParams.rev = doc._rev;
                    uri.search(requestParams);
                }
                _this.processRequest('PUT', uri.toString(), doc, headers, function (err, success) { if (err)
                    reject(err);
                else
                    resolve(success); });
            });
        };
        cblDB.prototype.processRequest = function (verb, url, data, headers, cb) {
            var http = new XMLHttpRequest();
            if (headers)
                _.forOwn(headers, function (value, key) { http.setRequestHeader(key, value); });
            http.onreadystatechange = function () {
                if (http.readyState == 4 && http.status == 200)
                    cb(false, JSON.parse(http.responseText));
                else
                    cb({ status: http.status, response: http.responseText });
            };
            http.open(verb, url, true);
            if (verb === 'GET' || verb === 'DELETE')
                http.send();
            else if (verb === 'POST' || verb === 'PUT')
                http.send(JSON.stringify(data));
        };
        return cblDB;
    })();
    return cblDB;
});

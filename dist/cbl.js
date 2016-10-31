///<reference path="typedefs/cblsubtypes.d.ts" />
define(["require", "exports"], function (require, exports) {
    "use strict";
    var cblDB = (function () {
        function cblDB(dbName, syncUrl) {
            this.dbName = '';
            this.lastChange = 0;
            this.dbUrl = '';
            this.localServerUrl = '';
            this.syncUrl = '';
            this.dbName = dbName.replace(/[^a-z0-9$_()+-/]/g, '');
            this.syncUrl = syncUrl;
        }
        cblDB.prototype.initDB = function (syncUrl) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                if (syncUrl)
                    _this.syncUrl = syncUrl;
                cbl.getServerURL(function (url) {
                    _this.localServerUrl = url;
                    _this.dbUrl = new URI(_this.localServerUrl).directory(_this.dbName).toString();
                    _this.processRequest('PUT', _this.dbUrl.toString(), null, null, function (err, response) {
                        if (err.status == 412)
                            resolve(err.response);
                        else if (response)
                            resolve(true);
                        else if (err)
                            reject(_this.buildError('Error From DB PUT Request with status: ' + err.status, err));
                        else
                            reject(_this.buildError('Unknown Error From DB PUT Request', {
                                res: response,
                                err: err
                            }));
                    });
                }, function (err) { throw new Error(err); });
            });
        };
        cblDB.prototype.activeTasks = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var verb = 'GET';
                var uri = new URI(_this.localServerUrl).segment('_active_tasks');
                _this.processRequest(verb, uri.toString(), null, null, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From activeTasks Request', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.allDocs = function (params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var verb = 'GET';
                var requestParams = {};
                if (params.keys) {
                    verb = 'POST';
                }
                else
                    requestParams = _.assign(requestParams, params);
                var uri = new URI(_this.dbUrl).segment('_all_docs').search(requestParams);
                _this.processRequest(verb, uri.toString(), params, null, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From allDocs Request', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.bulkDocs = function (body) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var uri = new URI(_this.dbUrl).segment('_bulk_docs');
                _this.processRequest('POST', uri.toString(), body, null, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From bulkDocs Request, ensure docs array is in request', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.changes = function (params) {
            var _this = this;
            return this.info()
                .then(function (info) {
                if (_this.lastChange === 0)
                    _this.lastChange = info.update_seq > 0 ? info.update_seq - 1 : 0;
                if (params.since === 'now') {
                    params.since = _this.lastChange;
                }
                _this.lastChange = info.update_seq;
                if (!params)
                    params = { feed: 'normal' };
                else
                    params.feed = 'normal';
                var uri = new URI(_this.dbUrl).segment('_changes').search(params);
                return new Promise(function (resolve, reject) {
                    _this.processRequest('GET', uri.toString(), null, null, function (err, success) {
                        if (err)
                            reject(_this.buildError('Error From _changes request', err));
                        else
                            resolve(success);
                    });
                });
            })
                .catch(function (err) { _this.buildError('Error From changes request for db info', err); });
        };
        cblDB.prototype.compact = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var uri = new URI(_this.dbUrl).segment('_compact');
                _this.processRequest('POST', uri.toString(), null, null, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From bulkDocs Request', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.destroy = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var uri = new URI(_this.dbUrl);
                _this.processRequest('DELETE', uri.toString(), null, null, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From bulkDocs Request', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.get = function (docId, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Accept': 'application/json' };
                var uri = new URI(_this.dbUrl).segment(docId);
                var requestParams = {};
                if (params) {
                    requestParams = _.assign(requestParams, params);
                    uri.search(requestParams);
                }
                _this.processRequest('GET', uri.toString(), null, headers, function (err, doc) {
                    if (err)
                        reject(_this.buildError('Error From GET Request', err));
                    else
                        resolve(doc);
                });
            });
        };
        cblDB.prototype.getAttachment = function (docId, attachmentName, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var uri = new URI(_this.dbUrl).segment(docId).segment(attachmentName);
                if (params.rev)
                    uri.search({ rev: params.rev });
                _this.processRequest('GET', uri.toString(), null, null, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From bulkDocs Request', err));
                    else
                        resolve(success);
                }, true);
            });
        };
        cblDB.prototype.info = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                _this.processRequest('GET', _this.dbUrl, null, null, function (err, info) {
                    if (err)
                        reject(_this.buildError('Error From db info Request', err));
                    else
                        resolve(info);
                });
            });
        };
        cblDB.prototype.infoRemote = function (remoteDBUrl) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                if (!remoteDBUrl)
                    remoteDBUrl = _this.syncUrl;
                _this.processRequest('GET', remoteDBUrl, null, null, function (err, info) {
                    if (err)
                        reject(_this.buildError('Error From db info remote Request', err));
                    else
                        resolve(info);
                });
            });
        };
        cblDB.prototype.post = function (doc, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var uri = new URI(_this.dbUrl);
                if (_.includes(params.batch, 'ok'))
                    uri.search({ batch: 'ok' });
                var headers = { 'Content-Type': 'application/json' };
                _this.processRequest('POST', uri.toString(), doc, headers, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From POST Doc Request', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.put = function (doc, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                if (!doc._id)
                    reject(_this.buildError('doc does not have _id for PUT request', doc));
                var headers = { 'Content-Type': 'application/json' };
                var requestParams = {};
                if (params) {
                    if (!params.rev)
                        requestParams.rev = doc._rev;
                    requestParams = _.assign(requestParams, params);
                }
                var uri = new URI(_this.dbUrl).segment(doc._id).search(requestParams);
                _this.processRequest('PUT', uri.toString(), doc, headers, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From PUT Request: ensure doc or params is providing the rev if updating a doc', err));
                    else
                        resolve(success);
                });
            });
        };
        cblDB.prototype.putAttachment = function (docId, attachmentId, attachment, mimeType, rev) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Content-Type': mimeType };
                var uri = new URI(_this.dbUrl).segment(docId).segment(attachmentId);
                if (rev)
                    uri.search({ rev: rev });
                _this.processRequest('PUT', uri.toString(), attachment, headers, function (err, success) {
                    if (err)
                        reject(_this.buildError('Error From PUT Attachment Request, if document exists ensure the rev is provided', err));
                    else
                        resolve(success);
                }, true);
            });
        };
        cblDB.prototype.query = function (view, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var verb = 'GET';
                var data = null;
                var headers = { 'Content-Type': 'application/json' };
                var jsonParams = [];
                var viewParts = view.split('/');
                var uri = new URI(_this.dbUrl).segment('_design').segment(viewParts[0]).segment('_view').segment(viewParts[1]);
                var fullURI = uri.toString();
                var requestParams = {};
                if (params) {
                    if (params.keys) {
                        verb = 'POST';
                        data = params;
                    }
                    else {
                        if (params.start_key)
                            params.startkey = params.start_key;
                        if (params.end_key)
                            params.endkey = params.end_key;
                        requestParams = _.assign(requestParams, params);
                        requestParams.update_seq = true;
                        if (params.key) {
                            if (_.isArray(params.key))
                                jsonParams.push('key=' + JSON.stringify(params.key));
                            else if (_.isString)
                                jsonParams.push('key="' + params.key + '"');
                            else if (_.isNumber)
                                jsonParams.push('key=' + params.key);
                            requestParams = _.omit(requestParams, 'key');
                        }
                        if (params.startkey || _.isNull(params.startkey)) {
                            if (_.isArray(params.startkey))
                                jsonParams.push('startkey=' + JSON.stringify(params.startkey));
                            else if (_.isString(params.startkey))
                                jsonParams.push('startkey="' + params.startkey + '"');
                            else if (_.isNumber(params.startkey))
                                jsonParams.push('startkey=' + params.startkey);
                            else if (_.isObject(params.startkey) || _.isNull(params.startkey))
                                jsonParams.push('startkey=' + JSON.stringify(params.startkey));
                            requestParams = _.omit(requestParams, ['startkey', 'start_key']);
                        }
                        if (params.endkey || _.isNull(params.startkey)) {
                            if (_.isArray(params.endkey))
                                jsonParams.push('endkey=' + JSON.stringify(params.endkey));
                            else if (_.isString(params.endkey))
                                jsonParams.push('endkey="' + params.endkey + '"');
                            else if (_.isNumber(params.endkey))
                                jsonParams.push('endkey=' + params.endkey);
                            else if (_.isObject(params.endkey) || _.isNull(params.endkey))
                                jsonParams.push('endkey=' + JSON.stringify(params.endkey));
                            requestParams = _.omit(requestParams, ['endkey', 'end_key']);
                        }
                        fullURI = uri.search(requestParams).toString();
                        _.each(jsonParams, function (param) { fullURI += '&' + param; });
                    }
                }
                _this.processRequest(verb, fullURI, data, headers, function (err, response) {
                    if (err)
                        reject(_this.buildError('Error From Query Request', err));
                    else
                        resolve(response);
                });
            });
        };
        cblDB.prototype.replicateTo = function (bodyRequest, otherDB) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Content-Type': 'application/json' };
                //options override the default behavior
                if (!bodyRequest) {
                    if (!otherDB && !_this.syncUrl)
                        reject(new Error('no sync url available to replicate to: ' + _this.dbName));
                    bodyRequest = { source: _this.dbName, target: otherDB ? otherDB : _this.syncUrl, continuous: false };
                }
                var uri = new URI(_this.localServerUrl).segment('_replicate');
                _this.processRequest('POST', uri.toString(), bodyRequest, headers, function (err, response) {
                    if (err)
                        reject(_this.buildError('Error: replicate to Request', err));
                    else
                        resolve(response);
                });
            });
        };
        cblDB.prototype.replicateFrom = function (bodyRequest, otherDB) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var headers = { 'Content-Type': 'application/json' };
                //options override the default behavior
                if (!bodyRequest) {
                    if (!otherDB && !_this.syncUrl)
                        reject(new Error('no sync url available to replicate from: ' + _this.dbName));
                    bodyRequest = { source: otherDB ? otherDB : _this.syncUrl, target: _this.dbName, continuous: false };
                }
                var uri = new URI(_this.localServerUrl).segment('_replicate');
                _this.processRequest('POST', uri.toString(), bodyRequest, headers, function (err, response) {
                    if (err)
                        reject(_this.buildError('Error: replicate from Request', err));
                    else
                        resolve(response);
                });
            });
        };
        cblDB.prototype.remove = function (doc, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var verb = 'DELETE';
                var requestParams = {};
                if (params)
                    requestParams = _.assign(requestParams, params);
                if (!params.rev)
                    requestParams.rev = doc._rev;
                var uri = new URI(_this.dbUrl).segment(doc._id).search(requestParams);
                _this.processRequest(verb, uri.toString(), null, null, function (err, response) {
                    if (err)
                        reject(_this.buildError('Error From remove Request', err));
                    else
                        resolve(response);
                });
            });
        };
        cblDB.prototype.removeAttachment = function (docId, attachmentId, rev) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var verb = 'DELETE';
                var uri = new URI(_this.dbUrl).segment(docId).segment(attachmentId).search({ rev: rev });
                _this.processRequest(verb, uri.toString(), null, null, function (err, response) {
                    if (err)
                        reject(_this.buildError('Error From remove Request', err));
                    else
                        resolve(response);
                });
            });
        };
        cblDB.prototype.revsDiff = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                reject(_this.buildError('revsDiff not implemented yet'));
                /** TODO: NEEDS IMPLEMENTATION */
            });
        };
        cblDB.prototype.upsert = function (doc, params) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var put = function (upsertDoc) {
                    if (!upsertDoc._id)
                        reject(_this.buildError('doc does not have _id for Upsert request', doc));
                    _this.processRequest('PUT', uri.toString(), upsertDoc, headers, function (err, success) {
                        if (err)
                            reject(_this.buildError('Error From Upsert Request', err));
                        else
                            resolve(success);
                    });
                };
                var headers = { 'Content-Type': 'application/json' };
                var uri = new URI(_this.dbUrl).segment(doc._id);
                var requestParams = {};
                if (params) {
                    requestParams = _.assign(requestParams, params);
                    uri.search(requestParams);
                }
                _this.get(doc._id)
                    .then(function (dbDoc) {
                    requestParams.rev = dbDoc._rev;
                    doc._rev = dbDoc._rev;
                    uri.search(requestParams);
                    return put(doc);
                })
                    .catch(function (error) {
                    if (error.status === 404)
                        put(doc);
                    else
                        return error;
                });
            });
        };
        cblDB.prototype.viewCleanup = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                reject(_this.buildError('viewCleanup not implemented yet'));
                /** TODO: NEEDS IMPLEMENTATION */
            });
        };
        cblDB.prototype.buildError = function (msg, err) {
            var error = new Error(msg);
            if (_.isObject(err))
                error = _.assign(error, err);
            else if (err)
                error.errorValue = err;
            error.dbName = this.dbName;
            return error;
        };
        cblDB.prototype.processRequest = function (verb, url, data, headers, cb, isAttach) {
            var http = new XMLHttpRequest();
            http.open(verb, url, true);
            if (headers)
                _.forOwn(headers, function (value, key) { http.setRequestHeader(key, value); });
            if (isAttach)
                http.responseType = 'blob'; //options "arraybuffer", "blob", "document", "json", and "text"
            //state change callback
            http.onreadystatechange = function () {
                if (http.readyState == 4 && http.status >= 200 && http.status <= 299) {
                    if (isAttach)
                        cb(false, http.response);
                    else
                        cb(false, JSON.parse(http.responseText), http);
                }
                else if (http.readyState == 4 && http.status >= 300)
                    cb({ status: http.status, response: http.responseText });
            };
            //send request variations
            if (verb === 'PUT' && isAttach)
                http.send(data);
            else if (verb === 'GET' || verb === 'DELETE')
                http.send();
            else if (verb === 'POST' || verb === 'PUT' && !_.isNull(data))
                http.send(JSON.stringify(data));
            else
                http.send();
        };
        cblDB.eventTypes = {
            active: 'active', change: 'change', complete: 'complete', denied: 'denied', error: 'error', paused: 'paused'
        };
        return cblDB;
    }());
    return cblDB;
});

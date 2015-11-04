///<reference path="cbl.d.ts" />

import Emitter = require('emitter');

class cblDB {

    private serverUrl = '';
    private dbName = '';
    private autoCompaction = false;
    private dbUrl:string = '';
    replicate = {
        to: this.replicateTo,
        from: this.replicateFrom
    };

    constructor(dbName:string, isAutoCompact?:boolean) {
        if (_.isBoolean(isAutoCompact)) this.autoCompaction = isAutoCompact;
        this.dbName = dbName.replace(/[^a-z0-9$_()+-/]/g, '');

        this.replicate = {
            from: this.replicateFrom,
            to: this.replicateTo
        }
    }

    initDB() {
        return new Promise((resolve, reject)=> {
            //get cbl server url
            cbl.getServerURL(
                (url)=> {
                    this.serverUrl = url;
                    this.dbUrl = new URI(this.serverUrl).directory(this.dbName).toString();
                    this.processRequest('PUT', this.dbUrl.toString(), null, null,
                        (err, response)=> {
                            if (err) reject(cblDB.buildError('Error From DB PUT Request', err));
                            else if (response.ok) resolve(true);
                            else if (response.status = 412) resolve(true);
                            else reject(cblDB.buildError('Error From DB PUT Request', response));
                        });
                },
                (err)=> {throw new Error(err); });
        });
    }

    allDocs(params:cbl.IAllDocsParams) {
        return new Promise((resolve, reject)=> {
            var uri = new URI(this.dbUrl);
            var verb = 'GET';
            var requestParams:cbl.IGetPostDbDesignViewName = <cbl.IGetPostDbDesignViewName>{};
            if (_.isArray(params.keys)) {
                verb = 'POST';
                requestParams.keys = params.keys;
            }
            else requestParams = <cbl.IGetPostDbDesignViewName>_.assign(requestParams, params);
            uri.search(requestParams);

            this.processRequest(verb, uri.toString(), null, null,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From allDocs Request', err));
                    else resolve(success);
                });
        });
    }

    bulkDocs(docs:Array<cbl.IDoc>) {
        return new Promise((resolve, reject)=> {
            var headers:cbl.IHeaders = {'Content-Type': 'application/json'};
            var uri = new URI(this.dbUrl);
            uri.segment('_bulk_docs');
            this.processRequest('POST', uri.toString(), docs, headers,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From bulkDocs Request', err));
                    else resolve(success);
                })
        });
    }

    changes(params:cbl.IGetDbChangesParams) {
        var http = new XMLHttpRequest();
        var emitter = new Emitter();
        var uri = new URI(this.dbUrl);
        uri.segment('_changes');
        http.onreadystatechange = () => {
            //if (http.readyState == 4 && http.status == 200) change(false, JSON.parse(http.responseText));
            //else error({status: http.status, response: http.responseText});
        };

        //http.open(verb, uri.toString(), true);
        //if (verb === 'GET' || verb === 'DELETE')http.send();
        //else if (verb === 'POST' || verb === 'PUT')http.send(JSON.stringify(data));
        return emitter;
    }

    compact() {
        return new Promise((resolve, reject)=> {
            var uri = new URI(this.dbUrl);
            uri.segment('_compact');
            this.processRequest('POST', uri.toString(), null, null,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From bulkDocs Request', err));
                    else resolve(success);
                });
        });
    }

    destroy() {
        return new Promise((resolve, reject)=> {
            var uri = new URI(this.dbUrl);
            this.processRequest('DELETE', uri.toString(), null, null,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From bulkDocs Request', err));
                    else resolve(success);
                });
        });
    }

    get(docId:string, params?:cbl.IGetDbDocParams) {
        return new Promise((resolve, reject)=> {
            var headers:cbl.IHeaders = {'Accept': 'application/json'};
            var uri = new URI(this.dbUrl);
            uri.segment(docId);
            var requestParams:cbl.IGetDbDocParams = <cbl.IGetDbDocParams>{};
            if (params) {
                requestParams = <cbl.IGetDbDocParams>_.assign(requestParams, params);
                uri.search(requestParams);
            }
            this.processRequest('GET', uri.toString(), null, headers,
                (err, doc)=> {
                    if (err) reject(cblDB.buildError('Error From GET Request', err));
                    else resolve(doc);
                });
        });
    }

    getAttachment(docId:string, attachmentName:string, rev?:string) {
        return new Promise((resolve, reject)=> {
            var uri:uri.URI = new URI(this.dbUrl);
            uri.segment(docId).segment(attachmentName);
            if (_.isString(rev)) uri.search({rev: rev});

            this.processRequest('GET', uri.toString(), null, null,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From bulkDocs Request', err));
                    else resolve(success);
                }, true);
        });
    }

    info() {
        //use allDocs to get doc count and sequence number and db ame for the db
        return new Promise((resolve, reject)=> {
            this.allDocs({update_seq: true})
                .then((info:cbl.IAllDocsResponse)=> {
                    resolve({'db_name': this.dbName, 'doc_count': info.total_rows, 'update_seq': info.update_seq})
                })
                .catch((err)=> {if (err) reject(cblDB.buildError('Error From info Request', err));})
        });
    }

    post(doc:cbl.IDoc, params:cbl.IPostDbDocParams) {
        return new Promise((resolve, reject)=> {
            var uri = new URI(this.dbUrl);
            if (params.batch === 'ok') uri.search({batch: 'ok'});
            var headers:cbl.IHeaders = {'Content-Type': 'application/json'};
            this.processRequest('POST', uri.toString(), doc, headers,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From POST Doc Request', err));
                    else resolve(success);
                });
        });
    }


    put(doc:cbl.IDoc, params:cbl.IPutDbDocParams) {
        return new Promise((resolve, reject)=> {
            if (!doc._id) reject(cblDB.buildError('doc does not have _id for PUT request', doc));
            var uri = new URI(this.dbUrl);
            uri.segment(doc._id);
            var headers:cbl.IHeaders = {'Content-Type': 'application/json'};
            var requestParams:cbl.IPutDbDocParams = <cbl.IPutDbDocParams>{};
            if (params) {
                requestParams = <cbl.IPutDbDocParams>_.assign(requestParams, params);
                uri.search(requestParams);
            }
            this.processRequest('PUT', uri.toString(), doc, headers,
                (err, success)=> {
                    if (err) reject(cblDB.buildError('Error From PUT Request', err));
                    else resolve(success);
                });
        });
    }

    putAttachment(docId:string, attachmentId:string, attachment:any, type:string) {
        return new Promise((resolve, reject)=> {
            var headers:cbl.IHeaders = {'Content-Type': type};
            var uri = new URI(this.dbUrl);
            uri.segment(docId).segment(attachmentId);
            this.processRequest('PUT', uri.toString(), attachment, headers,
                (err, success)=>{
                    if (err) reject(cblDB.buildError('Error From PUT Attachment Request', err));
                    else resolve(success);
                }, true);
        });
    }

    query(view:string, params:cbl.IGetPostDbDesignViewName) {
        return new Promise((resolve, reject)=> {
            var verb = 'GET';
            var headers:cbl.IHeaders = {'Content-Type': 'application/json'};
            var viewParts = view.split('/');
            var uri = new URI(this.dbUrl.toString());
            uri.segment('_design').segment(viewParts[0]).segment('_view').segment(viewParts[1]);
            var requestParams:cbl.IGetPostDbDesignViewName = <cbl.IGetPostDbDesignViewName>{};
            if (params.keys) {
                verb = 'POST';
                requestParams.keys = params.keys;
            }
            else requestParams = <cbl.IGetPostDbDesignViewName>_.assign(requestParams, params);
            uri.search(requestParams);

            this.processRequest(verb, uri.toString(), null, headers,
                (err, response)=> {
                    if (err) reject(cblDB.buildError('Error From Query Request', err));
                    else resolve(response);
                });
        });
    }

    static replicate() {
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    replicateFrom() {
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    replicateTo() {
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    remove() {
        return new Promise((resolve, reject)=> {

        });
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    removeAttachment() {
        return new Promise((resolve, reject)=> {

        });
    }

    revsDiff() {
        return new Promise((resolve, reject)=> {

        });
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    static sync() {
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    upsert(doc:cbl.IDoc, params?:cbl.IPutDbDocParams) {
        return new Promise((resolve, reject)=> {
            var put = (upsertDoc) => {
                if (!upsertDoc._id) reject(cblDB.buildError('doc does not have _id for Upsert request', doc));
                this.processRequest('PUT', uri.toString(), upsertDoc, headers,
                    (err, success)=> {
                        if (err) reject(cblDB.buildError('Error From Upsert Request', err));
                        else resolve(success);
                    });
            };

            var headers:cbl.IHeaders = {'Content-Type': 'application/json'};
            var uri = new URI(this.dbUrl);
            uri.segment(doc._id);
            var requestParams:cbl.IPutDbDocParams = <cbl.IPutDbDocParams>{};
            if (params) {
                requestParams = <cbl.IPutDbDocParams>_.assign(requestParams, params);
                uri.search(requestParams);
            }

            this.get(doc._id)
                .then((dbDoc:cbl.IDoc)=> {
                    requestParams.rev = dbDoc._rev;
                    doc._rev = dbDoc._rev;
                    uri.search(requestParams);
                    put(doc);
                })
                .catch((error)=> {
                    if (error.status === 404) put(doc);
                    else return error;
                });
        });
    }

    viewCleanup() {
        return new Promise((resolve, reject)=> {

        });
        /**
         * TODO: NEEDS IMPLEMENTATION
         */
    }

    private static buildError(msg:string, err) {
        var error:any = new Error(msg);
        if (_.isObject(err))error = _.assign(error, err);
        else  error.errorValue = err;
        return error;
    }

    private processRequest(verb:string, url:string, data:Object, headers:Object, cb:Function, isAttach?:boolean):void {
        var http = new XMLHttpRequest();
        http.open(verb, url, true);
        if (headers) _.forOwn(headers, (value, key)=> { http.setRequestHeader(key, value); });
        if(isAttach)http.responseType = 'blob'; //options "arraybuffer", "blob", "document", "json", and "text"

        //state change callback
        http.onreadystatechange = () => {
            if (http.readyState == 4 && http.status >= 200 && http.status <= 299){
                if(isAttach) cb(false, http.response);
                else cb(false, JSON.parse(http.responseText));
            }
            else if (http.readyState == 4 && http.status >= 300) cb({status: http.status, response: http.responseText});
        };

        //send request variations
        if(verb === 'PUT' && isAttach) http.send(data);
        else if (verb === 'GET' || verb === 'DELETE')http.send();
        else if (verb === 'POST' || verb === 'PUT' && !_.isNull(data))http.send(JSON.stringify(data));
        else http.send();
    }
}

export = cblDB;
///<reference path="cbl.d.ts" />

class cblDB {

    private serverUrl = '';
    private dbName = '';
    private dbUrl:uri.URI = null;
    replicate = null;

    constructor(dbName) {
        this.dbName = dbName;
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
                    this.dbUrl = new URI(this.serverUrl);
                    this.dbUrl.directory(this.dbName);
                    this.processRequest('PUT', this.dbName, null, null,
                        (err, response)=> {
                            if (err) reject(err);
                            else if (response.ok) resolve(true);
                            else if (response.status = 412) resolve(true);
                            else reject(response);
                        });
                },
                (err)=> {throw new Error(err); });
        });
    }

    get(docId:string, params?:Object) {
        return new Promise((resolve, reject)=> {
            this.processRequest('GET', this.dbUrl.directory(docId).toString(), null, null,
                (err, doc)=> { if (err) reject(err); else resolve(doc); });
        });
    }

    upsert(doc:cbl.cblDoc, params?:cbl.IPutDbDocParams) {
        return new Promise((resolve, reject)=> {
            var uri = this.dbUrl.directory(doc._id);
            var headers = {'Content-Type': 'application/json'};
            var requestParams:cbl.IPutDbDocParams = <cbl.IPutDbDocParams>{};
            if (params) requestParams = <cbl.IPutDbDocParams>_.assign(requestParams, params);
            if (doc._rev) {
                requestParams.rev = doc._rev;
                uri.search(requestParams);
            }

            this.processRequest('PUT', uri.toString(), doc, headers, (err, success)=> { if (err)reject(err); else resolve(success); })
        });
    }

    bulkDocs(docs:Array<Object>, params?:Object) {
        return new Promise((resolve, reject)=> {

        });
    }

    query(view:string, params?:Object) {
        return new Promise((resolve, reject)=> {
            this.processRequest('PUT', this.dbName + '/' + view, null, null,
                (err, response)=> { });
        });
    }

    changes() {
        return new Promise((resolve, reject)=> {

        });
    }

    info() {
        return new Promise((resolve, reject)=> {

        });
    }

    replicateFrom() {

    }

    replicateTo() {

    }

    destroy() {
        return new Promise((resolve, reject)=> {

        });
    }

    private processRequest(verb:string, url:string, data:Object, headers:Object, cb:Function):void {
        var http = new XMLHttpRequest();
        _.forOwn(headers, (value, key)=> { http.setRequestHeader(key, value); });

        http.onreadystatechange = () => {
            if (http.readyState == 4 && http.status == 200) cb(false, JSON.parse(http.responseText));
            else cb({status: http.status, response: http.responseText});
        };

        http.open(verb, url, true);
        if (verb === 'GET' || verb === 'DELETE')http.send();
        else if (verb === 'POST' || verb === 'PUT')http.send(JSON.stringify(data));
    }
}

export = cblDB;
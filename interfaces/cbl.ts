///<reference path="cbl.d.ts" />

class cblDB {

    private serverUrl = '';
    private dbName = '';
    replicate = null;

    constructor(dbName){
        this.dbName = dbName;
        this.replicate = {
            from:this.replicateFrom,
            to:this.replicateTo
        }
    }

    initDB(){
        return new Promise((resolve, reject)=>{
            //get cbl server url
            cbl.getServerURL(
                (url)=>{
                    this.serverUrl = url;
                    this.sendRequest('PUT',this.dbName, null, (data)=>{
                        if(data.ok) resolve(data.ok);
                        else if(data.status = 412) resolve(true);
                        else reject(data);
                    });
                },
                (err)=>{throw new Error(err); } );
        });
    }

    get(docId:string) {
        return new Promise((resolve, reject)=>{

        });
    }

    blindUpsert(){

    }

    bulkDocs(){

    }

    query(){

    }

    changes(){

    }

    info(){

    }

    replicateFrom(){

    }

    replicateTo(){

    }

    destroy(){
        
    }

    private sendRequest(verb:string, url:string, data:Object, cb:Function):void{
        var http = new XMLHttpRequest();

        http.onreadystatechange = function() {
            if (http.readyState == 4 && http.status == 200) {
                cb(JSON.parse(http.responseText));
            }
        };

        http.open(verb, this.serverUrl + url, true);
        if(data) http.send(JSON.stringify(data));
        else http.send();
    }
}

export = cblDB;
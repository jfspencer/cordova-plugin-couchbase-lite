/// <reference path="cblsubtypes.d.ts" />
/// <reference path="cblemitter.d.ts" />


declare module cblDB {

    interface instance {
        dbName:string;
        eventTypes:{active: string, change: string, complete: string, denied: string, error: string, paused: string };
        dbUrl:string;
        localServerUrl:string;
        syncUrl:string;
        serverUrl:string;
        constructor(dbName:string);
        initDB(): Promise<{}>;
        allDocs(params:cbl.IAllDocsParams): Promise<{}>;
        bulkDocs(docs:Array<cbl.IDoc>): Promise<{}>;
        changes(params:cbl.IGetDbChangesParams): EventEmitter.instance;
        compact(): Promise<{}>;
        destroy(): Promise<{}>;
        get(docId:string, params?:cbl.IGetDbDocParams): Promise<{}>;
        getAttachment(docId:string, attachmentName:string, params?:cbl.IBatchRevParams): Promise<{}>;
        info(): Promise<{}>;
        infoRemote(): Promise<{}>;
        post(doc:cbl.IDoc, params?:cbl.IPostDbDocParams): Promise<{}>;
        put(doc:cbl.IDoc, params?:cbl.IBatchRevParams): Promise<{}>;
        putAttachment(docId:string, attachmentId:string, attachment:any, mimeType:string, rev?:string): Promise<{}>;
        query(view:string, params:cbl.IDbDesignViewName): Promise<{}>;
        replicateFrom(bodyRequest?:cbl.IPostReplicateParams, otherDB?:string): EventEmitter.instance;
        replicateTo(bodyRequest?:cbl.IPostReplicateParams, otherDB?:string): EventEmitter.instance;
        remove(doc:cbl.IDoc, params?:cbl.IBatchRevParams): Promise<{}>;
        removeAttachment(docId:string, attachmentId:string, rev:string): Promise<{}>;
        revsDiff(): Promise<{}>;
        upsert(doc:cbl.IDoc, params?:cbl.IBatchRevParams): Promise<{}>;
        viewCleanup(): Promise<{}>;
        buildError(msg, err?);
        processRequest(verb, url, data, headers, cb, isAttach?);
    }
}
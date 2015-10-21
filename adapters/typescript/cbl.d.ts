///<reference path="typedefs/bluebird/bluebird.d.ts" />
///<reference path="typedefs/urijs/URIjs.d.ts" />
///<reference path="typedefs/lodash/lodash.d.ts" />


declare var cbl: cbl.IStatic;

// Support AMD require
declare module 'cbl' {
    export = cbl;
}

declare module cbl {
    interface IStatic {

        getServerURL(success:(url:string) => void, error:(error:any) => void):void;
    }

    interface cblDoc {
        _id:string;
        _rev?:string;
    }

    interface IGetDbChangesParams {
        attachments:boolean;
        att_encoding_info:boolean;
        conflicts:boolean;
        descending:boolean;
        doc_ids:string[];
        feed:string; //accepted values normal, continuous, eventsource, longpoll
        filter:string;
        heartbeat:number; //ms between empty line on continuous or longpoll changes default:60,000
        include_docs:boolean;
        'last-event-id':number;
        limit:number;
        since:number;
        style:string;
        timeout:number;
        view:string;
    }

    interface IPutDbDocParams {
        batch:string;
        rev:string;
    }
}
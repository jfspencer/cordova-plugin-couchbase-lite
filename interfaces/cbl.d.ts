declare var cbl: cbl.IStatic;
declare var Promise;

// Support AMD require
declare module 'cbl' {
    export = cbl;
}

declare module cbl {
    interface IStatic {

        getServerURL(success:(url:string) => void, error:(error:any) => void):void;
    }
}
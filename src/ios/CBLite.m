#import "CBLite.h"

#import "CouchbaseLite.h"
#import "CBLManager.h"
#import "CBLListener.h"
#import "CBLRegisterJSViewCompiler.h"
#import "CBLReplication.h"

#import <Cordova/CDV.h>

@implementation CBLite

static NSMutableDictionary *dbs;
static NSMutableDictionary *replications;

static CBLManager *dbmgr;
static NSThread *cblThread;

#pragma mark UTIL
- (void)changesDatabase:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        [[NSNotificationCenter defaultCenter]
         addObserverForName: kCBLDatabaseChangeNotification
         object: dbs[dbName]
         queue: nil
         usingBlock: ^(NSNotification *n) {
             NSArray* changes = n.userInfo[@"changes"];
             long lastSeq = [dbs[dbName] lastSequenceNumber];
             for (CBLDatabaseChange* change in changes){
                 CDVPluginResult* pluginResult =
                 [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                  messageAsString:[NSString stringWithFormat:@"{\"id\":\"%@\",\"is_delete\":%@,\"seq_num\":%ld}", change.documentID, change.isDeletion? @"true":@"false",lastSeq]];
                 [pluginResult setKeepCallbackAsBool:YES];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
             }
         }];
    });
}

- (void)changesReplication:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];

        [[NSNotificationCenter defaultCenter]
         addObserverForName:kCBLReplicationChangeNotification
         object:replications[[NSString stringWithFormat:@"%@%@", dbName, @"_push"]]
         queue:nil
         usingBlock:^(NSNotification *n) {
             CBLReplication *push = replications[[NSString stringWithFormat:@"%@%@", dbName, @"_push"]];
             NSString *response;
             BOOL active = (push.status == kCBLReplicationActive);
             if(active) response = [CBLite jsonSyncStatus:@"REPLICATION_ACTIVE" withDb:dbName withType:@"push"];
             else response = [CBLite jsonSyncStatus:@"REPLICATION_IDLE" withDb:dbName withType:@"push"];

             NSError *error = push.lastError ? push.lastError : nil;
             if(error != nil){
                 if(error.code == 401) response = [CBLite jsonSyncStatus:@"REPLICATION_UNAUTHORIZED" withDb:dbName withType:@"error_push"];
                 if(error.code == 404) response = [CBLite jsonSyncStatus:@"REPLICATION_NOT_FOUND" withDb:dbName withType:@"error_push"];
             }
             CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:response];
             [pluginResult setKeepCallbackAsBool:YES];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }];

        [[NSNotificationCenter defaultCenter]
         addObserverForName:kCBLReplicationChangeNotification
         object:replications[[NSString stringWithFormat:@"%@%@", dbName, @"_pull"]]
         queue:nil
         usingBlock:^(NSNotification *n) {
             CBLReplication *pull = replications[[NSString stringWithFormat:@"%@%@", dbName, @"_pull"]];
             NSString *response;
             BOOL active = (pull.status == kCBLReplicationActive);
             if(active) response = [CBLite jsonSyncStatus:@"REPLICATION_ACTIVE" withDb:dbName withType:@"pull"];
             else response = [CBLite jsonSyncStatus:@"REPLICATION_IDLE" withDb:dbName withType:@"pull"];

             NSError *error = pull.lastError ? pull.lastError : nil;
             if(error != nil){
                 if(error.code == 401) response = [CBLite jsonSyncStatus:@"REPLICATION_UNAUTHORIZED" withDb:dbName withType:@"error_pull"];
                 if(error.code == 404) response = [CBLite jsonSyncStatus:@"REPLICATION_NOT_FOUND" withDb:dbName withType:@"error_pull"];
             }
             CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:response];
             [pluginResult setKeepCallbackAsBool:YES];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
         }];
    });
}

+ (NSString *) jsonSyncStatus:(NSString *)status withDb:(NSString *)db withType:(NSString *)type {
    return [NSString stringWithFormat:@"{\"db\":\"%@\",\"type\": \"%@\" ,\"message\":\"%@\"}",db, type, status];
}


- (void)compact:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        CBLDatabase *db = dbs[dbName];
        NSError * _Nullable __autoreleasing * error2 = NULL;
        [db compact:error2];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"compact complete"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)info:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        CBLDatabase *db = dbs[dbName];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSUInteger:db.documentCount];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)initDb:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSError *error;
        if(dbs == nil){dbs = [NSMutableDictionary dictionary];}
        CBLDatabaseOptions *options = [[CBLDatabaseOptions alloc] init];
        options.create = YES;
        options.storageType = kCBLForestDBStorage;
        dbs[dbName] = [dbmgr openDatabaseNamed:dbName withOptions:options error:&error];
        CDVPluginResult* pluginResult;
        if (!dbs[dbName]) pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not init DB"];
        else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"CBL db init success"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)lastSequence:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSUInteger:[dbs[dbName] lastSequenceNumber]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];

}

- (void)replicateFrom:(CDVInvokedUrlCommand *)urlCommand {

}

- (void)replicateTo:(CDVInvokedUrlCommand *)urlCommand {

}

- (void)reset:(CDVInvokedUrlCommand *)urlCommand {
    [self onReset];
}

- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        for (NSString *r in replications) {
            CBLReplication * repl = replications[r];
            [repl stop];
        }
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"all replications stopped"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)sync:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSString* syncURL = [urlCommand.arguments objectAtIndex:1];
        NSString* user = [urlCommand.arguments objectAtIndex:2];
        NSString* pass = [urlCommand.arguments objectAtIndex:3];

        if(replications == nil){replications = [NSMutableDictionary dictionary];}

        if(replications[[NSString stringWithFormat:@"%@%@", dbName, @"_push"]] != nil){ [replications[[NSString stringWithFormat:@"%@%@", dbName, @"_push"]] stop]; }
        if(replications[[NSString stringWithFormat:@"%@%@", dbName, @"_pull"]] != nil){ [replications[[NSString stringWithFormat:@"%@%@", dbName, @"_pull"]] stop]; }

        CBLReplication *push = [dbs[dbName] createPushReplication: [NSURL URLWithString: syncURL]];
        CBLReplication *pull = [dbs[dbName] createPullReplication:[NSURL URLWithString: syncURL]];

        push.continuous = pull.continuous = YES;

        id<CBLAuthenticator> auth;
        auth = [CBLAuthenticator basicAuthenticatorWithName: user
                                                   password: pass];
        push.authenticator = pull.authenticator = auth;

        [push start]; [pull start];

        replications[[NSString stringWithFormat:@"%@%@", dbName, @"_push"]] = push;
        replications[[NSString stringWithFormat:@"%@%@", dbName, @"_pull"]] = pull;

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"native sync started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

#pragma mark READ
- (void)allDocs:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        int batchSize = 5000;
        CBLQuery* idQuery = [dbs[dbName] createAllDocumentsQuery];
        idQuery.allDocsMode = kCBLAllDocs;
        idQuery.prefetch = NO;

        NSError *idQueryError;
        NSMutableArray *allIds = [NSMutableArray array];
        CBLQueryEnumerator* allIdQuery = [idQuery run: &idQueryError];
        for (CBLQueryRow* row in allIdQuery) {
            @autoreleasepool {
                [allIds addObject:row.documentID];
            }
        }

        NSMutableArray *idBatches = [NSMutableArray array];
        NSUInteger remainingIds = [allIds count];
        int j = 0;

        while(remainingIds){
            @autoreleasepool {
                NSRange batchRange = NSMakeRange(j, MIN(batchSize, remainingIds));
                NSArray *batch = [allIds subarrayWithRange: batchRange];
                [idBatches addObject:batch];
                remainingIds -= batchRange.length;
                j += batchRange.length;
            }
        }

        for(NSArray *batch in idBatches){
            @autoreleasepool{
                [self processAllDocsBatch:batch withUrlCommand:urlCommand onDatabase:dbName];
            }
        }

        CDVPluginResult* finalPluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
        [finalPluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:finalPluginResult callbackId:urlCommand.callbackId];
    });
}

- (void) processAllDocsBatch:(NSArray *) batch withUrlCommand:(CDVInvokedUrlCommand *) urlCommand onDatabase:(NSString *)dbName {
    dispatch_cbl_async(cblThread, ^{
        @autoreleasepool{
            CBLQuery* batchQuery = [dbs[dbName] createAllDocumentsQuery];
            batchQuery.allDocsMode = kCBLAllDocs;
            batchQuery.prefetch = YES;
            batchQuery.keys = batch;

            NSError *queryError;
            CBLQueryEnumerator* batchResults = [batchQuery run: &queryError];
            NSMutableArray *responseBuffer = [[NSMutableArray alloc] init];
            for (CBLQueryRow* row in batchResults) {
                NSError *error;
                [responseBuffer addObject:[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:row.documentProperties
                                                                                                         options:0 //NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability
                                                                                                           error:&error] encoding:NSUTF8StringEncoding]];
            }
            NSString *response = [responseBuffer componentsJoinedByString:@","];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"[%@]", response]];
            [pluginResult setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
    });
}

- (void)get:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSString *id = [urlCommand.arguments objectAtIndex:1];
        NSString *isLocal = [urlCommand.arguments objectAtIndex:2];

        if([isLocal isEqualToString:@"true"]){
            CBLJSONDict *doc = [dbs[dbName] existingLocalDocumentWithID: id];
            if(doc != NULL){
                NSError *error2;
                NSData *json = [NSJSONSerialization dataWithJSONObject:doc options:0 error:&error2];
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
            else {
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"null"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
        }
        else {
            CBLDocument *doc = [dbs[dbName] existingDocumentWithID: id];
            if(doc == nil){
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"null"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
            NSError *error2;
            NSData *json = [NSJSONSerialization dataWithJSONObject:doc.properties options:0 error:&error2];
            CDVPluginResult* pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
    });
}

- (void)getDocRev:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSString *id = [urlCommand.arguments objectAtIndex:1];

        CBLDocument *doc = [dbs[dbName] existingDocumentWithID: id];
        if(doc == nil){
            CDVPluginResult* pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"null"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
        CDVPluginResult* pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:doc.currentRevisionID];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

#pragma mark WRITE
- (void)putAttachment:(CDVInvokedUrlCommand *)urlCommand{
    dispatch_cbl_async(cblThread, ^{
        @autoreleasepool{
            NSString* dbName = [urlCommand.arguments objectAtIndex:0];
            NSString* docId = [urlCommand.arguments objectAtIndex:1];
            NSString* fileName = [urlCommand.arguments objectAtIndex:2];
            NSString* name = [urlCommand.arguments objectAtIndex:3];
            NSString* mime = [urlCommand.arguments objectAtIndex:4];
            NSString* dirName = [urlCommand.arguments objectAtIndex:5];
            NSError *error;
            CBLDatabase *db = dbs[dbName];
            CBLDocument* doc = [db documentWithID: docId];
            CBLUnsavedRevision* newRev = [doc.currentRevision createRevision];

            NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *mediaPath = [NSString stringWithFormat:@"%@/%@", docsPath, dirName];
            NSString *filePath = [mediaPath stringByAppendingPathComponent:fileName];

            NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath];

            [newRev setAttachmentNamed: name
                       withContentType: mime
                               content: data];
            assert([newRev save: &error]);

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"attachment save success"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
    });
}

- (void)upsert:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSString* docId = [urlCommand.arguments objectAtIndex:1];
        NSString* jsonString = [urlCommand.arguments objectAtIndex:2];
        NSString* isLocal = [urlCommand.arguments objectAtIndex:3];

        NSStringEncoding  encoding = NSUTF8StringEncoding;
        NSData * jsonData = [jsonString dataUsingEncoding:encoding];
        NSError * error=nil;
        NSMutableDictionary * jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];

        if([isLocal isEqualToString:@"local"]){
            NSError * _Nullable __autoreleasing * error2 = NULL;
            [dbs[dbName] putLocalDocument:jsonDictionary withID:docId error: error2];
        }
        else {
            //try to get doc
            CBLDocument* doc = [dbs[dbName] existingDocumentWithID: docId];
            //if exists, force update
            if(doc != nil){
                if (![doc update: ^BOOL(CBLUnsavedRevision *newRev) {
                    [newRev setUserProperties:jsonDictionary];
                    return YES;
                } error: &error]) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"updated failed"];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
                }
                else {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"updated document"];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
                }
            }
            //if doesnt exist, create
            else {
                CBLDocument* newDoc = [dbs[dbName] documentWithID: docId];
                NSError* error;
                if (![newDoc putProperties: jsonDictionary error: &error]) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"failed to create document"];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
                }
                else {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"created document"];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
                }
            }
        }
    });
}

#pragma mark Plugin Boilerplate
- (void)pluginInitialize {
    [self launchCouchbaseLite];
}

- (void)onReset {
    dispatch_cbl_async(cblThread, ^{
        //cancel any change listeners
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:kCBLDatabaseChangeNotification
         object:nil];

        //cancel all replications
        for (NSString *r in replications) {
            CBLReplication * repl = replications[r];
            [repl stop];
        }

        replications = nil;
        dbs = nil;
    });
}

- (void)launchCouchbaseLite {
    cblThread = [[NSThread alloc] initWithTarget: self selector:@selector(cblThreadMain) object:nil];
    [cblThread start];

    dispatch_cbl_async(cblThread, ^{
        if(dbmgr != nil) [dbmgr close];
        if(dbs == nil){dbs = [NSMutableDictionary dictionary];}
        if(replications == nil){replications = [NSMutableDictionary dictionary];}
        if(dbmgr != nil) [dbmgr close];
        dbmgr = [[CBLManager alloc] init];
    });
}

void dispatch_cbl_async(NSThread* thread, dispatch_block_t block)
{
    if ([NSThread currentThread] == thread){ block(); }
    else{
        block = [block copy];
        [(id)block performSelector: @selector(invoke) onThread: thread withObject: nil waitUntilDone: NO];
    }
}

- (void)cblThreadMain
{
    // You need the NSPort here because a runloop with no sources or ports registered with it
    // will simply exit immediately instead of running forever.
    NSPort* keepAlive = [NSPort port];
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    [keepAlive scheduleInRunLoop: runLoop forMode: NSRunLoopCommonModes];
    [runLoop run];
}

@end

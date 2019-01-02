#import "CBLite.h"

#import "JobNimbus-Swift.h"

#import "CouchbaseLite.h"
#import "CBLManager.h"
#import "CBLListener.h"
#import "CBLRegisterJSViewCompiler.h"
#import "CBLReplication.h"
@import CallKit;
#import <Cordova/CDV.h>
#import <Raygun4iOS/Raygun.h>
#import <os/activity.h>
#import <os/log.h>

@implementation CBLite

static NSMutableDictionary *dbs;
static NSMutableDictionary *replications;
static NSMutableArray *callbacks;

static CBLReplication *pushPrimary;
static CBLReplication *pushMedia;

static CBLManager *dbmgr;
static NSThread *cblThread;
static ExtensionWriter *extWriter;

static os_log_t cbl_log;

#pragma mark UTIL
- (void)changesDatabase:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];

    [callbacks addObject:urlCommand.callbackId];

    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        [[NSNotificationCenter defaultCenter]
         addObserverForName: kCBLDatabaseChangeNotification
         object: dbs[dbName]
         queue: nil
         usingBlock: ^(NSNotification *n) {
             NSArray* changes = n.userInfo[@"changes"];
             for (CBLDatabaseChange* change in changes){
                 long lastSeq = [dbs[dbName] lastSequenceNumber];
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

    [callbacks addObject:urlCommand.callbackId];

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
        
        //check database engine type package contains files with .forest
        NSFileManager *filemgr = [NSFileManager defaultManager];
        NSArray<NSURL *> *paths = [filemgr URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
        NSURL *appSupportURL = paths[0];
        NSURL *cblBaseURL = [appSupportURL URLByAppendingPathComponent:@"CouchbaseLite"];
        NSURL *dbURL = [cblBaseURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.cblite2",dbName]];
        
        NSError *error;
        NSFileWrapper *cblDb = [[NSFileWrapper alloc] initWithURL:dbURL options:NSFileWrapperReadingImmediate error:&error];
        NSDictionary *cblDbContents = [cblDb fileWrappers];
        NSFileWrapper *sqliteDb = cblDbContents[@"db.sqlite3"];
        
        NSString *isSqlite = nil;
        if (sqliteDb != nil) { isSqlite = @"true"; }
        else { isSqlite = @"false"; }
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsString:
                                         [NSString stringWithFormat:@"{\"count\":%lu,\"isSqlite\":\"%@\"}", db.documentCount, isSqlite]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void) initCallerID:(CDVInvokedUrlCommand *)urlCommand {
    os_log_debug(cbl_log, "start initCallerID");
    
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    extWriter = [[ExtensionWriter alloc] init];
    [extWriter initCallerIdDb:dbName];
    
    [[CXCallDirectoryManager sharedInstance]
     getEnabledStatusForExtensionWithIdentifier:@"com.jobnimbus.JobNimbus2.CallerID"
     completionHandler:^(CXCallDirectoryEnabledStatus enabledStatus, NSError * _Nullable error) {
         NSString *hasCallerId = nil;
         if(enabledStatus == CXCallDirectoryEnabledStatusEnabled){ hasCallerId = @"true"; }
         else {hasCallerId = @"false";}
         
         
         
         CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                           messageAsString:
                                          [NSString stringWithFormat:@"{\"callerIdEnabled\":\"%@\"}", hasCallerId]];
         [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
     }];
}

- (void)initDb:(CDVInvokedUrlCommand *)urlCommand {
    os_log_debug(cbl_log, "initDb: enter -----------------------------------------------");
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSError *error;
        if(dbs == nil){dbs = [NSMutableDictionary dictionary];}

        // Used to migrate away from forestDB after user re-installs app
        Boolean exists = [dbmgr databaseExistsNamed:dbName];
        if(exists){
            CBLDatabaseOptions *options = [[CBLDatabaseOptions alloc] init];
            dbs[dbName] = [dbmgr openDatabaseNamed:dbName withOptions:options error:&error];
        }
        else {
            CBLDatabaseOptions *options = [[CBLDatabaseOptions alloc] init];
            options.create = YES;
            options.storageType = kCBLSQLiteStorage;
            os_log_debug(cbl_log, "initDb: start openDatabaseNamed... -----------------------------------------------");
            dbs[dbName] = [dbmgr openDatabaseNamed:dbName withOptions:options error:&error];
        }
        
        CBLView* primaryRecordView = [dbs[dbName] viewNamed: @"primaryRecord"];
        [primaryRecordView setMapBlock: MAPBLOCK({
            if ([doc[@"type"] isEqual: @"contact"]) {
                //(@{@"_id":doc[@"_id"], @"type":doc[@"type"], @"status_name":doc[@"status_name"], @"first_name":doc[@"first_name"], @"last_name":doc[@"last_name"], @"owners":doc[@"owners"]}))
                emit(@"contact", @"");
            }
            else if([doc[@"type"] isEqual: @"job"]) {
                //(@{@"_id":doc[@"_id"], @"type":doc[@"type"], @"status_name":doc[@"status_name"], @"name":doc[@"name"], @"owners":doc[@"owners"]})
                emit(@"job", @"");
            }
            
            else if([doc[@"type"] isEqual: @"task"]) {
                //(@{@"_id":doc[@"_id"], @"type":doc[@"type"], @"title":doc[@"title"], @"date_start":doc[@"date_start"], @"date_end":doc[@"date_end"]})
                emit(@"task", @"");
            }
        }) version: @"4"];
        
        CDVPluginResult* pluginResult;
        if (!dbs[dbName]) pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not init DB"];
        else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"CBL db init success"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)startPushReplication:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* syncURL = [urlCommand.arguments objectAtIndex:1];
    NSString* user = [urlCommand.arguments objectAtIndex:2];
    NSString* pass = [urlCommand.arguments objectAtIndex:3];

    pushPrimary = [dbs[dbName] createPushReplication: [NSURL URLWithString: syncURL]];
    pushMedia = [dbs[[NSString stringWithFormat:@"%@%@", dbName, @"_media"]] createPushReplication:[NSURL URLWithString: syncURL]];

    pushPrimary.continuous = pushMedia.continuous = NO;

    id<CBLAuthenticator> auth;
    auth = [CBLAuthenticator basicAuthenticatorWithName: user
                                               password: pass];
    pushPrimary.authenticator = pushMedia.authenticator = auth;

    [pushPrimary start]; [pushMedia start];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSUInteger:[dbs[dbName] lastSequenceNumber]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)pushReplicationIsRunning:(CDVInvokedUrlCommand *)urlCommand {
    BOOL primaryIsRunning = NO;
    BOOL mediaIsRunning = NO;
    if(pushPrimary){ primaryIsRunning = pushPrimary.running; }
    if(pushMedia){ mediaIsRunning = pushMedia.running; }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:primaryIsRunning || mediaIsRunning];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)deleteUserDbs:(CDVInvokedUrlCommand *) urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString *dbName = [urlCommand.arguments objectAtIndex:0];

        //close and clean up primary and media databases
        for (NSString *cbId in callbacks){
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
            [pluginResult setKeepCallbackAsBool:NO];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:cbId];
        }

        [callbacks removeAllObjects];
        [self onReset];
        [dbmgr close];

        //delete primary and media database files
        NSFileManager *filemgr = [NSFileManager defaultManager];
        NSArray<NSURL *> *paths = [filemgr URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
        NSURL *appSupportURL = paths[0];
        NSURL *cblBaseURL = [appSupportURL URLByAppendingPathComponent:@"CouchbaseLite"];
        NSURL *dbPrimaryURL = [cblBaseURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.cblite2",dbName]];
        NSURL *dbMediaURL = [cblBaseURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@_media.cblite2",dbName]];

        NSError *error;
        [filemgr removeItemAtURL:dbPrimaryURL error:&error];

        NSError *mediaError;
        [filemgr removeItemAtURL:dbMediaURL error:&mediaError];

        //restart cbl on a new thread, new manager
        pushMedia = nil;
        pushPrimary = nil;
        [self launchCouchbaseLite];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
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



- (void)buildViewDocs:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        CBLQuery* query = [[dbs[dbName] viewNamed: @"primaryRecord"] createQuery];
        query.keys = @[@"job"];
        query.prefetch = YES;
        query.indexUpdateMode = kCBLUpdateIndexAfter;
        
        NSError *idQueryError;
        CBLQueryEnumerator* queryRunner = [query run: &idQueryError];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsString: @"done"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)viewDocs:(CDVInvokedUrlCommand *)urlCommand {
    dispatch_cbl_async(cblThread, ^{
        //keep the plugin open for additional call backs
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        
        //pull out input params
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSString* type = [urlCommand.arguments objectAtIndex:1] != nil ? [urlCommand.arguments objectAtIndex:1] : @"";
        
        //create a query
        CBLQuery* query = [[dbs[dbName] viewNamed: @"primaryRecord"] createQuery];
        query.keys = @[type];
        query.prefetch = YES;
        query.indexUpdateMode = kCBLUpdateIndexAfter;
        
        NSError *idQueryError;
        int batchSize = 500;
        NSMutableArray *queryDocs = [NSMutableArray array];
        CBLQueryEnumerator* queryRunner = [query run: &idQueryError];
        for (CBLQueryRow* row in queryRunner) {
            
            @autoreleasepool { [queryDocs addObject:row.documentProperties]; }
        }
        
        NSUInteger remainingIds = [queryDocs count];
        int j = 0;
        
        while(remainingIds){
            @autoreleasepool {
                NSRange batchRange = NSMakeRange(j, MIN(batchSize, remainingIds));
                NSArray *batch = [queryDocs subarrayWithRange: batchRange];
                @autoreleasepool{ [self processViewBatch:batch withUrlCommand:urlCommand onDatabase:dbName]; }
                remainingIds -= batchRange.length;
                j += batchRange.length;
            }
        }
        
        CDVPluginResult* finalPluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"complete"];
        [finalPluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:finalPluginResult callbackId:urlCommand.callbackId];
    });
}

- (void) processViewBatch:(NSArray *) batch withUrlCommand:(CDVInvokedUrlCommand *) urlCommand onDatabase:(NSString *)dbName {
    dispatch_cbl_async(cblThread, ^{
        @autoreleasepool{
            NSMutableArray *responseBuffer = [[NSMutableArray alloc] init];
            for (CBLJSONDict* props in batch) {
                NSError *error;
                @try{
                    //TODO read row.doc props send raygun when nil
                    NSData *data = [NSJSONSerialization dataWithJSONObject:props
                                                                   options:0 //or NSJSONWritingPrettyPrinted
                                                                     error:&error];
                    [responseBuffer addObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                }
                @catch(NSException *e){
                    os_log_debug(cbl_log, "failed to read data row");
                }
            }
            CDVPluginResult* pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[[NSString stringWithFormat:@"[%@]", [responseBuffer componentsJoinedByString:@","]] dataUsingEncoding:NSUTF8StringEncoding]];
            [pluginResult setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
    });
}

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
                [self processBatch:batch withUrlCommand:urlCommand onDatabase:dbName];
            }
        }

        [[CXCallDirectoryManager sharedInstance] getEnabledStatusForExtensionWithIdentifier:@"com.jobnimbus.JobNimbus2.CallerID"
                                                  completionHandler:^(CXCallDirectoryEnabledStatus enabledStatus, NSError * _Nullable error) {
                                                      if(enabledStatus == CXCallDirectoryEnabledStatusEnabled){
                                                          [[CXCallDirectoryManager sharedInstance] reloadExtensionWithIdentifier:@"com.jobnimbus.JobNimbus2.CallerID" completionHandler:^(NSError *n) {
                                                              [extWriter updateLogFiles];
                                                              if(n != nil){ os_log_debug(cbl_log, "CALLERID : failed to update callerID Extension : CALLERID"); }
                                                              else { os_log_debug(cbl_log, "CALLERID : trigger directory update"); }
                                                          }];
                                                      }
                                                  }];

        CDVPluginResult* finalPluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"complete"];
        [finalPluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:finalPluginResult callbackId:urlCommand.callbackId];
    });
}

- (void) processBatch:(NSArray *) batch withUrlCommand:(CDVInvokedUrlCommand *) urlCommand onDatabase:(NSString *)dbName {
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
                @try{
                    //TODO read row.doc props send raygun when nil
                    NSData *data = [NSJSONSerialization dataWithJSONObject:row.documentProperties
                                                                   options:0 //or NSJSONWritingPrettyPrinted
                                                                     error:&error];
                    [responseBuffer addObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                    [extWriter upsertData:row];
                }
                @catch(NSException *e){
                    os_log_debug(cbl_log, "failed to read data row");
                }
            }

            CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[[NSString stringWithFormat:@"[%@]", [responseBuffer componentsJoinedByString:@","]] dataUsingEncoding:NSUTF8StringEncoding]];
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
        NSError *error;
        if([isLocal isEqualToString:@"true"]){
            CBLJSONDict *doc = [dbs[dbName] existingLocalDocumentWithID: id];
            if(doc != nil){
                @try {
                    CDVPluginResult* pluginResult =
                    [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[NSJSONSerialization dataWithJSONObject:doc options:0 error:&error]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
                }
                @catch (NSException *exception) {
                    CDVPluginResult* pluginResult =
                    [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[@"null" dataUsingEncoding:NSUTF8StringEncoding]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
                }
            }
            else {
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[@"null" dataUsingEncoding:NSUTF8StringEncoding]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
        }
        else {
            CBLDocument *doc = [dbs[dbName] existingDocumentWithID: id];
            if(doc == nil){
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[@"null" dataUsingEncoding:NSUTF8StringEncoding]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
            @try {
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[NSJSONSerialization dataWithJSONObject:doc.properties options:0 error:&error]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
            @catch (NSException *exception) {
                CDVPluginResult* pluginResult =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:[@"null" dataUsingEncoding:NSUTF8StringEncoding]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
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
- (void)deleteLocal:(CDVInvokedUrlCommand *)urlCommand{
    dispatch_cbl_async(cblThread, ^{
        NSString* dbName = [urlCommand.arguments objectAtIndex:0];
        NSString* docId = [urlCommand.arguments objectAtIndex:1];
        NSError *error;
        if(![dbs[dbName] deleteLocalDocumentWithID:docId error:&error]){
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"local delete failure"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
        else {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
    });
}

- (void)putAttachment:(CDVInvokedUrlCommand *)urlCommand{
    dispatch_cbl_async(cblThread, ^{
        os_activity_t putAttachment_activity = os_activity_create("CBL putAttachment", OS_ACTIVITY_CURRENT,OS_ACTIVITY_FLAG_DEFAULT);
        os_activity_scope(putAttachment_activity);
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

            @try{
                [newRev setAttachmentNamed: name
                           withContentType: mime
                                   content: data];
                [newRev save: &error];
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
            @catch(NSException *e){
                [[Raygun sharedReporter] send:e];
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"putAttachment failure"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
            }
        }
    });
}

//returns attachment count for a specific document in the database
- (void)attachmentCount:(CDVInvokedUrlCommand *) urlCommand {
    dispatch_cbl_async(cblThread, ^{
        @try{
            NSString* dbName = [urlCommand.arguments objectAtIndex:0];
            NSString* docId = [urlCommand.arguments objectAtIndex:1];
            CBLDocument* doc = [dbs[dbName] documentWithID: docId];
            CBLRevision* rev = doc.currentRevision;
            NSArray<CBLAttachment *> *attachments = rev.attachments;

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSUInteger:attachments.count];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
        }
        @catch(NSException *e){
            [[Raygun sharedReporter] send:e];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"attachmentCount Exception: %@, Reason:%@", [e name], [e reason]]];
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
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"saved local document"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
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

        //cancel all callbacks
        for (NSString *cbId in callbacks){
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
            [pluginResult setKeepCallbackAsBool:NO];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:cbId];
        }

        [callbacks removeAllObjects];
        [replications removeAllObjects];
        [dbs removeAllObjects];
    });
}

- (void)resetCallbacks:(CDVInvokedUrlCommand *)urlCommand {
    //cancel all callbacks
    dispatch_cbl_async(cblThread, ^{
        for (NSString *cbId in callbacks){
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
            [pluginResult setKeepCallbackAsBool:NO];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:cbId];
        }

        [callbacks removeAllObjects];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"callbacks reset"];
        [pluginResult setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    });
}

- (void)launchCouchbaseLite {
    cbl_log = os_log_create("com.jobnimbus.JobNimbus2", "CBL");
    cblThread = [[NSThread alloc] initWithTarget: self selector:@selector(cblThreadMain) object:nil];
    [cblThread start];

    dispatch_cbl_async(cblThread, ^{
        if(dbmgr != nil) [dbmgr close];
        if(dbs == nil){dbs = [NSMutableDictionary dictionary];}
        if(replications == nil){replications = [NSMutableDictionary dictionary];}
        if(callbacks == nil){callbacks = [NSMutableArray array];}
        if(dbmgr != nil) [dbmgr close];
        //[CBLManager enableLogging: @"SyncVerbose"];
        //[CBLManager enableLogging: @"Database"];
        //[CBLManager enableLogging: @"RemoteRequest"];
        //[CBLManager enableLogging: @"ChangeTracker"];
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

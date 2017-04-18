#import "CBLite.h"

#import "CouchbaseLite.h"
#import "CBLManager.h"
#import "CBLListener.h"
#import "CBLRegisterJSViewCompiler.h"
#import "CBLReplication.h"

#import <Cordova/CDV.h>

@implementation CBLite

@synthesize dbmgr;

static NSMutableDictionary *dbs;
static NSMutableDictionary *replications;

#pragma mark UTIL
- (void)changes:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];

    [[NSNotificationCenter defaultCenter]
     addObserverForName: kCBLDatabaseChangeNotification
     object: dbs[dbName]
     queue: nil
     usingBlock: ^(NSNotification *n) {
         NSArray* changes = n.userInfo[@"changes"];
         for (CBLDatabaseChange* change in changes){
             NSLog(@"Document '%@' changed.", change.documentID);
             CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:change.documentID];
             [pluginResult setKeepCallbackAsBool:YES];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
         }
     }];
}

- (void)compact:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    CBLDatabase *db = dbs[dbName];
    NSError * _Nullable __autoreleasing * error = NULL;
    [db compact:error];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"compact complete"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)info:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    CBLDatabase *db = dbs[dbName];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSUInteger:db.documentCount];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)initDb:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult;
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSError *error;
    if(dbs == nil){dbs = [NSMutableDictionary dictionary];}
    dbs[dbName] = [dbmgr databaseNamed: dbName error: &error];
    if (!dbs[dbName]) pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not init DB"];
    else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"CBL db init success"];
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
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];

    CBLDatabase *db = dbs[dbName];
    if (db != nil) {
        for (CBLReplication *r in db.allReplications) {
            [r stop];
        }
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"replication stopped"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)sync:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* syncURL = [urlCommand.arguments objectAtIndex:1];
    NSString* user = [urlCommand.arguments objectAtIndex:2];
    NSString* pass = [urlCommand.arguments objectAtIndex:3];

    if(replications == nil){replications = [NSMutableDictionary dictionary];}

    if(replications[[NSString stringWithFormat:@"%@/%@", dbName, @"_push"]] != nil){ [replications[[NSString stringWithFormat:@"%@/%@", dbName, @"_push"]] stop]; }
    if(replications[[NSString stringWithFormat:@"%@/%@", dbName, @"_pull"]] != nil){ [replications[[NSString stringWithFormat:@"%@/%@", dbName, @"_pull"]] stop]; }

    CBLReplication *push = [dbs[dbName] createPushReplication: [NSURL URLWithString: syncURL]];
    CBLReplication *pull = [dbs[dbName] createPullReplication:[NSURL URLWithString: syncURL]];

    push.continuous = pull.continuous = YES;

    id<CBLAuthenticator> auth;
    auth = [CBLAuthenticator basicAuthenticatorWithName: user
                                               password: pass];
    push.authenticator = pull.authenticator = auth;

    [push start]; [pull start];

    replications[[NSString stringWithFormat:@"%@/%@", dbName, @"_push"]] = push;
    replications[[NSString stringWithFormat:@"%@/%@", dbName, @"_pull"]] = pull;

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"native sync started"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

#pragma mark READ
- (void)allDocs:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    //NSString* limitString = [urlCommand.arguments objectAtIndex:1];
    //NSInteger limit = [limitString integerValue];

    CBLQuery* query = [dbs[dbName] createAllDocumentsQuery];
    query.allDocsMode = kCBLAllDocs;
    //query.limit = limit;
    NSError *error;
    CBLQueryEnumerator* result = [query run: &error];
    for (CBLQueryRow* row in result) {
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:row.documentProperties
                                                           options:0 //NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                             error:&error];
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:json];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"{}"];
    [pluginResult setKeepCallbackAsBool:NO];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)get:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString *id = [urlCommand.arguments objectAtIndex:1];
    CBLDocument *doc = [dbs[dbName] documentWithID: id];
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:doc.properties
                                                       options:0 // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    CDVPluginResult* pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}


#pragma mark WRITE
- (void)putAttachment:(CDVInvokedUrlCommand *)urlCommand{
    //TODO update to new API
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

- (void)upsert:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* docId = [urlCommand.arguments objectAtIndex:1];
    NSString* jsonString = [urlCommand.arguments objectAtIndex:2];

    NSStringEncoding  encoding = NSUTF8StringEncoding;
    NSData * jsonData = [jsonString dataUsingEncoding:encoding];
    NSError * error=nil;
    NSDictionary * jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];


    //try to get doc
    CBLDocument* doc = [dbs[dbName] existingDocumentWithID: docId];
    //if exists, force update
    if(doc != nil){
        if (![doc putProperties: jsonDictionary error: &error]) {
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

#pragma mark Plugin Boilerplate
- (void)pluginInitialize {
    [self launchCouchbaseLite];
}

- (void)onReset {
    //cancel any change listeners
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:kCBLDatabaseChangeNotification
     object:nil];

    //cancel all replications
    for (CBLDatabase *db in dbs) {
        for (CBLReplication *r in db.allReplications) {
            [r stop];
        }
    }

    replications = nil;
    dbs = nil;
}

- (void)launchCouchbaseLite {
    if(dbmgr != nil) [dbmgr close];
    NSLog(@"Launching Couchbase Lite...");
    dbmgr = [CBLManager sharedInstance];
    CBLRegisterJSViewCompiler();
#if 1
    // Couchbase Lite 1.0's CBLRegisterJSViewCompiler function doesn't register the filter compiler
    if ([CBLDatabase filterCompiler] == nil) {
        Class cblJSFilterCompiler = NSClassFromString(@"CBLJSFilterCompiler");
        [CBLDatabase setFilterCompiler: [[cblJSFilterCompiler alloc] init]];
    }
#endif
}

@end
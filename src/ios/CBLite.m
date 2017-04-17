#import "CBLite.h"

#import "CouchbaseLite.h"
#import "CBLManager.h"
#import "CBLListener.h"
#import "CBLRegisterJSViewCompiler.h"
#import "CBLReplication.h"

#import <Cordova/CDV.h>

@implementation CBLite

@synthesize dbmgr;

CBLReplication *push;
CBLReplication *pull;
static NSMutableDictionary *activeDbs;

#pragma UTIL
- (void)changes:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];

    [[NSNotificationCenter defaultCenter]
     addObserverForName: kCBLDatabaseChangeNotification
     object: activeDbs[dbName]
     queue: nil
     usingBlock: ^(NSNotification *n) {
         NSArray* changes = n.userInfo[@"changes"];
         for (CBLDatabaseChange* change in changes){
             NSLog(@"Document '%@' changed.", change.documentID);
             CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:change.documentID];
             [pluginResult setKeepCallbackAsBool:YES];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
         }
     }
     ];
}

- (void)compact:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    CBLDatabase *db = activeDbs[dbName];
    NSError * _Nullable __autoreleasing * error = NULL;
    [db compact:error];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"compact complete"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)info:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    CBLDatabase *db = activeDbs[dbName];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSUInteger:db.documentCount];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)initDb:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult;
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSError *error;
    if(activeDbs == nil){activeDbs = [NSMutableDictionary dictionary];}
    activeDbs[dbName] = [dbmgr databaseNamed: dbName error: &error];
    if (!activeDbs[dbName]) pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not init DB"];
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

    CBLDatabase *db = activeDbs[dbName];
    if (db != nil) {
        for (CBLReplication *r in db.allReplications) {
            [r stop];
        }
    }
    else NSLog(@"could not stop replication");

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"replication stopped"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)sync:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* syncURL = [urlCommand.arguments objectAtIndex:1];
    NSString* user = [urlCommand.arguments objectAtIndex:2];
    NSString* pass = [urlCommand.arguments objectAtIndex:3];

    push = [activeDbs[dbName] createPushReplication: [NSURL URLWithString: syncURL]];
    pull = [activeDbs[dbName] createPullReplication:[NSURL URLWithString: syncURL]];

    push.continuous = pull.continuous = NO;
    id<CBLAuthenticator> auth;
    auth = [CBLAuthenticator basicAuthenticatorWithName: user
                                               password: pass];
    push.authenticator = pull.authenticator = auth;

    [push start]; [pull start];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"native sync started"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}



#pragma READ
- (void)allDocs:(CDVInvokedUrlCommand *)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* limitString = [urlCommand.arguments objectAtIndex:1];
    NSInteger limit = [limitString integerValue];

    CBLQuery* query = [activeDbs[dbName] createAllDocumentsQuery];
    query.allDocsMode = kCBLAllDocs;
    query.limit = limit;
    NSError *error;
    CBLQueryEnumerator* result = [query run: &error];
    for (CBLQueryRow* row in result) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:row.documentProperties
                                                           options:0 //NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                             error:&error];

        if (! jsonData) {
            NSLog(@"Got an error: %@", error);
        } else {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
}

- (void)get:(CDVInvokedUrlCommand *)urlCommand {

}


#pragma WRITE
- (void)putAttachment:(CDVInvokedUrlCommand *)urlCommand{
    //TODO update to new API
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* docId = [urlCommand.arguments objectAtIndex:1];
    NSString* fileName = [urlCommand.arguments objectAtIndex:2];
    NSString* name = [urlCommand.arguments objectAtIndex:3];
    NSString* mime = [urlCommand.arguments objectAtIndex:4];
    NSString* dirName = [urlCommand.arguments objectAtIndex:5];

    NSError *error;
    CBLDatabase *db = activeDbs[dbName];

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

}

#pragma Plugin Boilerplate
- (void)pluginInitialize {
    [self launchCouchbaseLite];
}

- (void)onReset {
    //cancel any change listeners
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:kCBLDatabaseChangeNotification
     object:nil];
    activeDbs = nil;
    push = nil;
    pull = nil;
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
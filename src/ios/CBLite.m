#import "CBLite.h"

#import "CouchbaseLite.h"
#import "CBLManager.h"
#import "CBLListener.h"
#import "CBLRegisterJSViewCompiler.h"
#import "CBLReplication.h"

#import <Cordova/CDV.h>

@implementation CBLite

@synthesize liteURL;
@synthesize dbmgr;

CBLReplication *push;
CBLReplication *pull;
static NSMutableDictionary *activeDbs;

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
    self.liteURL = dbmgr.internalURL;
    NSLog(@"Couchbase Lite url = %@", self.liteURL);
}

- (void)getURL:(CDVInvokedUrlCommand*)urlCommand {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}



- (void)isReplicating:(CDVInvokedUrlCommand*)urlCommand {
    CDVPluginResult* pluginResult = nil;
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    
    NSError *error;
    CBLDatabase *db = [dbmgr existingDatabaseNamed: dbName error: &error];

    if (db != nil) {
        if([db.allReplications count] > 0)pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"true"];
        else pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"false"];
    }
    else{
        NSLog(@"could not determine replication state");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"false"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand {
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    [self getDB:dbName];
    
    CBLDatabase *db = [self getDB:dbName];
    if (db != nil) {
        for (CBLReplication *r in db.allReplications) {
            [r stop];
        }
    }
    else NSLog(@"could not stop replication");

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (CBLDatabase*)getDB:(NSString *)dbName {
    NSError *error;
    CBLDatabase *db = [dbmgr existingDatabaseNamed: dbName error: &error];
    
    if(db == nil) return nil;
    else return db;
}

- (void)closeManager:(CDVInvokedUrlCommand*)urlCommand {
    if(dbmgr != nil) [dbmgr close];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

-(void)relaunchManager:(CDVInvokedUrlCommand *)urlCommand {
    [self launchCouchbaseLite];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void) dbSync:(CDVInvokedUrlCommand *)urlCommand{
    NSError *error;
    
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* syncURL = [urlCommand.arguments objectAtIndex:1];
    NSString* user = [urlCommand.arguments objectAtIndex:2];
    NSString* pass = [urlCommand.arguments objectAtIndex:3];
    
    CBLDatabase *db = [dbmgr existingDatabaseNamed: dbName error: &error];
    
    push = [db createPushReplication: [NSURL URLWithString: syncURL]];
    pull = [db createPullReplication:[NSURL URLWithString: syncURL]];
    
    push.continuous = pull.continuous = NO;
    id<CBLAuthenticator> auth;
    auth = [CBLAuthenticator basicAuthenticatorWithName: user
                                               password: pass];
    
    push.authenticator = pull.authenticator = auth;
    
    [push start];
    [pull start];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"native sync started"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}


//////////_______UTIL_______\\\\\\\\\\

- (void)activeTasks:(CDVInvokedUrlCommand *)urlCommand {
    //Implementation pending
}

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
    
}

- (void)destroy:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)info:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)initDb:(CDVInvokedUrlCommand *)urlCommand {
    CDVPluginResult* pluginResult;
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSError *error;
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

- (void)revsDiff:(CDVInvokedUrlCommand *)urlCommand {
    
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

- (void)viewCleanup:(CDVInvokedUrlCommand *)urlCommand {
    
}

//////////_______READ_______\\\\\\\\\\

- (void)allDocs:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)get:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)getAttachment:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)query:(CDVInvokedUrlCommand *)urlCommand {
    
}


//////////_______WRITE_______\\\\\\\\\\

- (void)bulkDocs:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)post:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)put:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)putAttachment:(CDVInvokedUrlCommand *)urlCommand{
    //TODO update to new API
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSString* docId = [urlCommand.arguments objectAtIndex:1];
    NSString* fileName = [urlCommand.arguments objectAtIndex:2];
    NSString* name = [urlCommand.arguments objectAtIndex:3];
    NSString* mime = [urlCommand.arguments objectAtIndex:4];
    
    NSError *error;
    CBLDatabase *db = [dbmgr existingDatabaseNamed: dbName error: &error];
    
    CBLDocument* doc = [db documentWithID: docId];
    CBLUnsavedRevision* newRev = [doc.currentRevision createRevision];
    
    NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *mediaPath = [NSString stringWithFormat:@"%@/%@", docsPath, @"media"];
    NSString *filePath = [mediaPath stringByAppendingPathComponent:fileName];
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath];
    
    [newRev setAttachmentNamed: name
               withContentType: mime
                       content: data];
    assert([newRev save: &error]);
    
    // The replications are running now; the -replicationChanged: method will
    // be called with notifications when their status changes.
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"attachment save success"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)remove:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)removeAttachment:(CDVInvokedUrlCommand *)urlCommand {
    
}

- (void)upsert:(CDVInvokedUrlCommand *)urlCommand {
    
}

@end

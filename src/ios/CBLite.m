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

- (void)pluginInitialize {
    [self launchCouchbaseLite];
}

- (void)getURL:(CDVInvokedUrlCommand*)urlCommand
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)isReplicating:(CDVInvokedUrlCommand*)urlCommand
{
    CDVPluginResult* pluginResult = nil;
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    
    NSError *error;
    CBLDatabase *db = [dbmgr existingDatabaseNamed: dbName error: &error];

    if (db != nil) {
        if([db.allReplications count] > 0){
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"true"];
        }else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"false"];
        }
    }
    else{
        NSLog(@"could not determine replication state");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"false"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand
{
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    [self getDB:dbName];
    
    CBLDatabase *db = [self getDB:dbName];
    if (db != nil) {
        for (CBLReplication *r in db.allReplications) {
            [r stop];
        }
    }
    else{
        NSLog(@"could not stop replication");
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (CBLDatabase*)getDB:(NSString *)dbName
{
    NSError *error;
    CBLDatabase *db = [dbmgr existingDatabaseNamed: dbName error: &error];
    
    if(db == nil){
        return nil;
    }
    else return db;
}

- (void)closeManager:(CDVInvokedUrlCommand*)urlCommand
{
    if(dbmgr != nil){
        [dbmgr close];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

-(void)relaunchManager:(CDVInvokedUrlCommand *)urlCommand{

    [self launchCouchbaseLite];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
}

- (void)putAttachment:(CDVInvokedUrlCommand *)urlCommand{
    
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

- (void)launchCouchbaseLite
{
    if(dbmgr != nil){
        [dbmgr close];
    }
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

@end

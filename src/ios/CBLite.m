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
    
    CBLDatabase *db = [self getDB:dbName];
    if (db != nil) {
        int replCount = 0;
        for (CBLReplication *r in db.allReplications) {
            replCount += 1;
        }
        if(replCount > 0){
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

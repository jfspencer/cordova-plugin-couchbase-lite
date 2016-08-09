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

- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand
{
    NSString* dbName = [urlCommand.arguments objectAtIndex:0];
    NSError *error;
    CBLDatabase *database = [dbmgr existingDatabaseNamed: dbName error: &error];
    if (database != nil) {
        NSArray<CBLReplication *> *replications = database.allReplications;
        for (CBLReplication *replication in replications) {
            [replication stop];
        }
    }
    else{
        NSLog(@"could not stop replication");
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[self.liteURL absoluteString]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:urlCommand.callbackId];
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

#import <Cordova/CDV.h>
#import "CBLManager.h"

@class ExtensionWriter;

@interface CBLite : CDVPlugin

@property (nonatomic, strong) CBLManager *dbmgr;

//UTIL
- (void)changesDatabase:(CDVInvokedUrlCommand*)urlCommand;
- (void)changesReplication:(CDVInvokedUrlCommand*)urlCommand;
- (void)compact:(CDVInvokedUrlCommand*)urlCommand;
- (void)info:(CDVInvokedUrlCommand*)urlCommand;
- (void)initCallerID:(CDVInvokedUrlCommand*)urlCommand;
- (void)initDb:(CDVInvokedUrlCommand*)urlCommand;
- (void)lastSequence:(CDVInvokedUrlCommand*)urlCommand;
- (void)replicateFrom:(CDVInvokedUrlCommand*)urlCommand;
- (void)replicateTo:(CDVInvokedUrlCommand*)urlCommand;
- (void)reset:(CDVInvokedUrlCommand*)urlCommand;
- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand;
- (void)sync:(CDVInvokedUrlCommand*)urlCommand;
- (void)resetCallbacks:(CDVInvokedUrlCommand*)urlCommand;

- (void)startPushReplication:(CDVInvokedUrlCommand*)urlCommand;
- (void)pushReplicationIsRunning:(CDVInvokedUrlCommand*)urlCommand;
- (void)deleteUserDbs:(CDVInvokedUrlCommand*)urlCommand;

//READ
- (void)buildViewDocs:(CDVInvokedUrlCommand*)urlCommand;
- (void)viewDocs:(CDVInvokedUrlCommand*)urlCommand;
- (void)allDocs:(CDVInvokedUrlCommand*)urlCommand;
- (void)get:(CDVInvokedUrlCommand*)urlCommand;
- (void)getDocRev:(CDVInvokedUrlCommand*)urlCommand;
- (void)attachmentCount:(CDVInvokedUrlCommand*)urlCommand;

//WRITE
- (void)deleteLocal:(CDVInvokedUrlCommand*)urlCommand;
- (void)putAttachment:(CDVInvokedUrlCommand*)urlCommand;
- (void)upsert:(CDVInvokedUrlCommand*)urlCommand;
@end

#import <Cordova/CDV.h>
#import "CBLManager.h"

@interface CBLite : CDVPlugin

@property (nonatomic, strong) NSURL *liteURL;
@property (nonatomic, strong) CBLManager *dbmgr;

//complete API
- (void)activeTasks:(CDVInvokedUrlCommand*)urlCommand;
- (void)changes:(CDVInvokedUrlCommand*)urlCommand;
- (void)compact:(CDVInvokedUrlCommand*)urlCommand;
- (void)destroy:(CDVInvokedUrlCommand*)urlCommand;
- (void)info:(CDVInvokedUrlCommand*)urlCommand;
- (void)initDb:(CDVInvokedUrlCommand*)urlCommand;
- (void)replicateFrom:(CDVInvokedUrlCommand*)urlCommand;
- (void)replicateTo:(CDVInvokedUrlCommand*)urlCommand;
- (void)reset:(CDVInvokedUrlCommand*)urlCommand;
- (void)revsDiff:(CDVInvokedUrlCommand*)urlCommand;
- (void)sync:(CDVInvokedUrlCommand*)urlCommand;
- (void)viewCleanup:(CDVInvokedUrlCommand*)urlCommand;
- (void)allDocs:(CDVInvokedUrlCommand*)urlCommand;
- (void)get:(CDVInvokedUrlCommand*)urlCommand;
- (void)getAttachment:(CDVInvokedUrlCommand*)urlCommand;
- (void)query:(CDVInvokedUrlCommand*)urlCommand;
- (void)bulkDocs:(CDVInvokedUrlCommand*)urlCommand;
- (void)post:(CDVInvokedUrlCommand*)urlCommand;
- (void)put:(CDVInvokedUrlCommand*)urlCommand;
- (void)remove:(CDVInvokedUrlCommand*)urlCommand;
- (void)removeAttachment:(CDVInvokedUrlCommand*)urlCommand;
- (void)upsert:(CDVInvokedUrlCommand*)urlCommand;

//UTIL
- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand;
- (void)relaunchManager:(CDVInvokedUrlCommand*)urlCommand;
- (void)closeManager:(CDVInvokedUrlCommand*)urlCommand;
- (void)isReplicating:(CDVInvokedUrlCommand*)urlCommand;
- (void)putAttachment:(CDVInvokedUrlCommand*)urlCommand;

@end

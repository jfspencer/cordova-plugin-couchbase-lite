#import <Cordova/CDV.h>
#import "CBLManager.h"

@interface CBLite : CDVPlugin

@property (nonatomic, strong) CBLManager *dbmgr;

//UTIL
- (void)changes:(CDVInvokedUrlCommand*)urlCommand;
- (void)compact:(CDVInvokedUrlCommand*)urlCommand;
- (void)info:(CDVInvokedUrlCommand*)urlCommand;
- (void)initDb:(CDVInvokedUrlCommand*)urlCommand;
- (void)replicateFrom:(CDVInvokedUrlCommand*)urlCommand;
- (void)replicateTo:(CDVInvokedUrlCommand*)urlCommand;
- (void)reset:(CDVInvokedUrlCommand*)urlCommand;
- (void)stopReplication:(CDVInvokedUrlCommand*)urlCommand;
- (void)sync:(CDVInvokedUrlCommand*)urlCommand;

//READ
- (void)allDocs:(CDVInvokedUrlCommand*)urlCommand;
- (void)get:(CDVInvokedUrlCommand*)urlCommand;

//WRITE
- (void)putAttachment:(CDVInvokedUrlCommand*)urlCommand;
- (void)upsert:(CDVInvokedUrlCommand*)urlCommand;
@end
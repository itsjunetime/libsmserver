#import <MRYIPCCenter.h>
#import "substrate.h"

@interface NSObject (Undocumented)
+ (id)description;
@end

@interface CKConversationList
- (id)conversationForExistingChatWithGroupID:(id)arg1;
+ (id)sharedConversationList;
@end

@interface CKConversation
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
@end

@interface CKComposition : NSObject
- (id)initWithText:(id)arg1 subject:(id)arg2;
- (id)compositionByAppendingMediaObject:(id)arg1;
@end

@interface CKMessage
@end

@interface CKMediaObject : NSObject
@end

@interface CKMediaObjectManager : NSObject
+ (id)sharedInstance;
- (id)mediaObjectWithFileURL:(id)arg1 filename:(id)arg2 transcoderUserInfo:(id)arg3 attributionInfo:(id)arg4 hideAttachment:(_Bool)arg5;
@end

@interface UIApplication (Undocumented)
- (_Bool)launchApplicationWithIdentifier:(id)arg1 suspended:(_Bool)arg2;
+ (id)sharedApplication;
@end

@interface NSConcreteNotification
- (id)object;
- (id)userInfo;
@end

@interface IMChat {
	NSString *_identifier;
}
@end

@interface IMHandle : NSObject {
	NSString *_id;
}
@end

@interface IMMessage : NSObject {
	IMHandle *_subject;
}
@end

@interface FBProcessManager : NSObject
+ (id)sharedInstance;
- (id)allProcesses;
- (id)processesForBundleIdentifier:(id)arg1;
- (id)allApplicationProcesses;
@end

%hook SMSApplication

@interface SMServerIPC : NSObject
@end

@implementation SMServerIPC {
	MRYIPCCenter* _center;
}

+(void)load {
	[self sharedInstance];
}

+(instancetype)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static SMServerIPC* sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

-(instancetype)init {
	if ((self = [super init])) {
		_center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
		[_center addTarget:self action:@selector(sendText:)];
	}
	return self;
}

- (void)sendText:(NSDictionary *)vals {

	NSArray* attachments = vals[@"attachment"];
	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];
	
	CKConversationList* list = [%c(CKConversationList) sharedConversationList];
	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];
	
	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];
	
	CKComposition* composition = [[%c(CKComposition) alloc] initWithText:text subject:nil];
	CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

	for (NSString* obj in attachments) {
		
		NSString *new_string = [NSString stringWithFormat:@"file://%@", obj];
		NSURL *file_url = [NSURL URLWithString:new_string];
		
		CKMediaObject* object = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:nil attributionInfo:@{} hideAttachment:NO];
		composition = [composition compositionByAppendingMediaObject:object];
	}
	
	CKMessage* message = [conversation messageWithComposition:composition];

	[conversation sendMessage:message newComposition:YES];
}

@end

- (_Bool)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		SMServerIPC* center = [SMServerIPC sharedInstance];
	});

	NSLog(@"LibSMServer_app: Launched application");

	return %orig;
}

- (void)_messageReceived:(id)arg1 {
    
	NSLog(@"LibSMServer_app: Received a message");

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		//NSArray *proc = [[%c(FBProcessManager) sharedInstance] processesForBundleIdentifier:@"com.ianwelker.smserver"];

		//if (proc.count != 0) { /// Ideally this would check to make sure SMServer is open before computing, but it's always returning NO so we're not doing that for now.
			NSLog(@"LibSMServer_app: Found that SMServer is running, sending IPC...");

			IMChat *chat = (IMChat *)[(NSConcreteNotification *)arg1 object];
			NSString *chat_id = MSHookIvar<NSString *>(chat, "_identifier");

			MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
			[center callExternalMethod:@selector(handleReceivedTextWithCallback:) withArguments:chat_id];
		//}
	});

	NSLog(@"LibSMServer_app: Got past async, calling orig.");

	%orig;
}

- (void)_messageSent:(id)arg1 {
	NSLog(@"LibSMServer_app: Sent a message: %@", [arg1 description]);

	//NSArray *proc = [[%c(FBProcessManager) sharedInstance] processesForBundleIdentifier:@"com.ianwelker.smserver"];
	//NSArray *procs = [%c(FBProcessManager) allProcesses];
	//NSArray *shared = [[%c(FBProcessManager) sharedInstance] allProcesses];
	//NSArray *apps = [[%c(FBProcessManager) sharedInstance] allApplicationProcesses];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		//NSLog(@"LibSMServer_app: Checking processes: %@, shared: %@, apps: %@, count: %lu", [procs description], [shared description], [apps description], proc.count);

		//if (proc.count != 0) { /// Ideally this would check to make sure SMServer is open before computing, but it's always returning NO so we're not doing that for now.
			NSLog(@"LibSMServer_app: SMServer app is open, continuing.");

			IMMessage *message = (IMMessage *)[[(NSConcreteNotification *)arg1 userInfo] objectForKey:@"__kIMChatRegistryMessageSentMessageKey"];
			NSLog(@"LibSMServer_app: got IMMessage: %@", [message description]);
			
			IMHandle *handle = MSHookIvar<IMHandle *>(message, "_subject");
			NSLog(@"LibSMServer_app: got IMHandle: %@", [handle description]);

			NSString *chat_id = MSHookIvar<NSString *>(handle, "_id");
			NSLog(@"LibSMServer_app: Got chat_id for sent message: %@", chat_id);

			MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
			[center callExternalMethod:@selector(handleReceivedTextWithCallback:) withArguments:chat_id];
		//}
	});

	NSLog(@"LibSMServer_app: Got past starting async, calling orig.");

	%orig;
}

%end

%hook Springboard

@interface NSBundle (Undocumented)
+ (id)mainBundle;
@property (readonly, copy) NSString *bundleIdentifier;
@end

@interface LaunchSMSIPC : NSObject
@end

@implementation LaunchSMSIPC {
	MRYIPCCenter* _center;
}

+(void)load {
	[self sharedInstance];
}

+(instancetype)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static LaunchSMSIPC* sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

-(instancetype)init {
	if ((self = [super init])) {
		_center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverLaunch"];
		[_center addTarget:self action:@selector(launchSMS)];
		[_center addTarget:self action:@selector(relaunchSMServer)];
	}
	return self;
}

- (void)launchSMS {
	NSLog(@"LibSMServer_app: called LaunchSMS");

	NSArray *proc = [[%c(FBProcessManager) sharedInstance] processesForBundleIdentifier:@"com.apple.MobileSMS"];
	
	if (proc.count == 0) { /// Always YES rn for some reason
		[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
	}
}

- (void)relaunchSMServer {
	NSLog(@"LibSMServer_app: called relaunchSMServer");

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.ianwelker.smserver" suspended:YES];

	/// Also reopen mobileSMS 'cause it can be shut down if the server is running for too long
	NSArray *proc = [[%c(FBProcessManager) sharedInstance] processesForBundleIdentifier:@"com.apple.MobileSMS"];
	
	if (proc.count == 0) { /// Always YES rn for some reason
		NSLog(@"LibSMServer_app: Actually restarting MobileSMS");

		[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
	}
}

@end

%end

%ctor {
	
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		NSLog(@"LibSMServer_app: called ctor for springboard in %@", bundleID);
		LaunchSMSIPC* center = [LaunchSMSIPC sharedInstance];
	}
}
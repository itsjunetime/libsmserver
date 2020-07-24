#import <MRYIPCCenter.h>
#import "substrate.h"

@interface NSObject (Undocumented)
+ (id)description;
@end

@interface __NSCFString
@end

@interface CKConversationList
+ (id)sharedConversationList;
- (id)conversationForExistingChatWithGroupID:(id)arg1;
- (id)conversationForHandles:(id)arg1 displayName:(id)arg2 joinedChatsOnly:(_Bool)arg3 create:(_Bool)arg4;
@end

@interface CKConversation : NSObject
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
- (void)setLocalUserIsTyping:(_Bool)arg1;
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

@interface IMChat : NSObject {
	NSString *_identifier;
}
- (void)sendMessage:(id)arg1;
@end

@interface IMChatRegistry
+ (id)sharedInstance;
- (id)chatForIMHandle:(id)arg1;
@end

@interface IMHandle : NSObject {
	NSString *_id;
}
- (id)initWithAccount:(id)arg1 ID:(id)arg2 alreadyCanonical:(_Bool)arg3;
@end

@interface IMMessage : NSObject {
	IMHandle *_subject;
}
+ (id)instantMessageWithText:(id)arg1 flags:(unsigned long long)arg2;
@end

@interface IMAccount : NSObject
@end

@interface IMAccountController : NSObject
+ (id)sharedInstance;
- (id)mostLoggedInAccount;
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
		[_center addTarget:self action:@selector(setTyping:inConversation:)];
	}
	return self;
}

- (void)sendText:(NSDictionary *)vals {

	NSArray* attachments = vals[@"attachment"];
	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];
	
	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];
	
	CKConversationList* list = [%c(CKConversationList) sharedConversationList];
	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];
	
	if (conversation != nil) { /// If they've texted this person before
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

	} else { /// If they haven't

		IMAccountController *sharedAccountController = [%c(IMAccountController) sharedInstance];
		IMAccount *myAccount = [sharedAccountController mostLoggedInAccount];
		
		__NSCFString *handleId = (__NSCFString *)address;
		IMHandle *handle = [[%c(IMHandle) alloc] initWithAccount:myAccount ID:handleId alreadyCanonical:YES];
		
		IMChatRegistry *registry = [%c(IMChatRegistry) sharedInstance];
		IMChat *chat = [registry chatForIMHandle:handle];

		/// Flags is always just 1048581 in a regular message, with/without images/videos.
		/// 19922949 with a instant recording
		IMMessage *immessage = [%c(IMMessage) instantMessageWithText:text flags:1048581];

		[chat sendMessage:immessage];
	}
}

- (void)setTyping:(NSDictionary *)vals { /// Will be used when I implement typing indicators
	NSLog(@"LibSMServer_app: Received typing");
	_Bool is = [vals[@"isTyping"] isEqualToString:@"YES"]; /// Since you can't directly pass _Bools through NSDictionaries
	NSString *address = vals[@"address"];
	NSLog(@"LibSMServer_app: Got vals for typing: %@, %@", is ? @"YES" : @"NO", address);

	CKConversationList *sharedList = [%c(CKConversationList) sharedConversationList];
	CKConversation *convo =  [sharedList conversationForExistingChatWithGroupID:address];
	NSLog(@"LibSMServer_app: Got shared list & convo. Sending...");

	[convo setLocalUserIsTyping:is];
	NSLog(@"LibSMServer_app: Set typing: %@ for address: %@", is ? @"true" : @"false", address);
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

		NSLog(@"LibSMServer_app: Found that SMServer is running, sending IPC...");

		IMChat *chat = (IMChat *)[(NSConcreteNotification *)arg1 object];
		NSString *chat_id = MSHookIvar<NSString *>(chat, "_identifier");

		MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		[center callExternalMethod:@selector(handleReceivedTextWithCallback:) withArguments:chat_id];
	});

	NSLog(@"LibSMServer_app: Got past async, calling orig.");

	%orig;
}

- (void)_messageSent:(id)arg1 {
	NSLog(@"LibSMServer_app: Sent a message: %@", [arg1 description]);

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		IMMessage *message = (IMMessage *)[[(NSConcreteNotification *)arg1 userInfo] objectForKey:@"__kIMChatRegistryMessageSentMessageKey"];
			
		if (message != nil) {

			IMHandle *handle = MSHookIvar<IMHandle *>(message, "_subject");

			NSString *chat_id = MSHookIvar<NSString *>(handle, "_id");

			MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
			[center callExternalMethod:@selector(handleReceivedTextWithCallback:) withArguments:chat_id];

		}
	});

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

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
}

- (void)relaunchSMServer {
	NSLog(@"LibSMServer_app: called relaunchSMServer");

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.ianwelker.smserver" suspended:YES];

	/// Also reopen mobileSMS 'cause it can be shut down if the server is running for too long
	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
}

@end

%end

%ctor {
	
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		LaunchSMSIPC* center = [LaunchSMSIPC sharedInstance];
	}
}
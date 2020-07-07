#import <MRYIPCCenter.h>

@interface CKConversationList
- (id)conversationForExistingChatWithGroupID:(id)arg1;
+ (id)sharedConversationList;
@end

@interface CKConversation
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
@end

@interface CKComposition
- (id)initWithText:(id)arg1 subject:(id)arg2;
@end

@interface CKMessage
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
		[_center addTarget:self action:@selector(handleText:)];
	}
	return self;
}

- (void)handleText:(NSDictionary *)vals {

	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];

	CKConversationList* list = [%c(CKConversationList) sharedConversationList];

	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];
	CKComposition* composition = [[%c(CKComposition) alloc] initWithText:text subject:nil];

	CKMessage* message = [conversation messageWithComposition:composition];
	[conversation sendMessage:message newComposition:YES];
}

@end

- (_Bool)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {

	[[%c(NSNotificationCenter) defaultCenter] addObserver:self selector:@selector(notiCallback:) name:(NSNotificationName)@"smserverSend" object:nil];

	SMServerIPC* center = [SMServerIPC sharedInstance];

	return %orig;
}

%end
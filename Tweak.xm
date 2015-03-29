#import "../PS.h"

//#include "InspCWrapper.m"

CFStringRef domain = CFSTR("/var/mobile/Library/Preferences/com.PS.MorePredict");
CFStringRef PreferencesNotification = CFSTR("com.PS.MorePredict.prefs");
CFStringRef landscapeKey = CFSTR("UIPredictionCountForLandscape");
CFStringRef portraitKey = CFSTR("UIPredictionCountForPortrait");
CFStringRef gapKey = CFSTR("UIPredictionGap");

@interface TIKeyboardCandidate : NSObject
@end

@interface TIKeyboardCandidateSingle : TIKeyboardCandidate
@property(assign, nonatomic) NSString *candidate;
@property(assign, nonatomic) NSString *input;
@end

@interface TIZephyrCandidate : TIKeyboardCandidateSingle
@end

@interface TIAutocorrectionList : NSObject
+ (TIAutocorrectionList *)listWithAutocorrection:(TIZephyrCandidate *)autocorrection predictions:(NSArray *)predictions;
- (TIAutocorrectionList *)autocorrection;
- (NSArray *)predictions;
@end

@interface UIKeyboardAutocorrectionController : NSObject
@property BOOL needsAutocorrection;
@property BOOL deferredAutocorrection;
@property BOOL requestedAutocorrection;
@property(retain, nonatomic) TIAutocorrectionList *autocorrectionList;
- (void)updateSuggestionViews;
- (void)clearAutocorrection;
- (void)setNeedsAutocorrection;
@end

@interface UIKeyboardImpl : NSObject
+ (UIKeyboardImpl *)activeInstance;
- (UIKeyboardAutocorrectionController *)autocorrectionController;
- (UIInterfaceOrientation)interfaceOrientation;
@end

@interface UIInputSwitcherView
+ (UIInputSwitcherView *)activeInstance;
- (void)toggleKeyboardPredictionPreference;
@end

@interface UIMorphingLabel : UILabel
@end

@interface UIKeyboardPredictionCell : UIView
@property CGRect collapsedFrame;
@property CGRect activeFrame;
@property CGRect baseFrame;
@property(retain, nonatomic, readonly) UIMorphingLabel *label;
@end

@interface UIKeyboardPredictionView : UIView
@property NSInteger state;
@property BOOL show;
+ (NSUInteger)numberOfCandidates;
+ (CGFloat)predictionViewHeightForState:(NSInteger)state orientation:(UIInterfaceOrientation)orientation;
+ (CGFloat)overlapHeight;
- (void)setPredictionViewState:(NSInteger)state animate:(BOOL)animate notify:(BOOL)notify;
- (void)setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection;
- (void)_setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection;
@end

@interface UIKeyboardInputManager : NSObject
@end

@interface TIKeyboardInputManagerZephyr : UIKeyboardInputManager
- (NSArray *)completionCandidates;
- (NSIndexSet *)indexesOfDuplicatesInCandidates:(NSArray *)candidates;
- (TIZephyrCandidate *)topCandidate;
- (TIZephyrCandidate *)extendedAutocorrection:(TIZephyrCandidate *)autocorrection spanningInputsForCandidates:(NSArray *)candidates;
- (TIAutocorrectionList *)autocorrectionListForEmptyInputWithDesiredCandidateCount:(NSUInteger)count;
@end

extern "C" void setCellRect(UIKeyboardPredictionCell *cell, CGRect frame, NSUInteger index, NSUInteger count)
{
	BOOL isLast = (index == count - 1);
	BOOL notHeadOrTail = index == 0 || isLast;
	CGFloat gap = [%c(UIKeyboardPredictionView) overlapHeight];
	CGFloat cellWidth = (frame.size.width - (count - 1) * gap) / count;
	CGFloat cellHeight = frame.size.height;
	CGFloat cellX = index == 0 ? 0 : (index * (cellWidth + gap));
	CGRect cellFrame = CGRectMake(cellX, 0, cellWidth, cellHeight);
	CGFloat activeWidth = cellWidth + (notHeadOrTail ? (2 * gap) : gap);
	CGRect activeFrame = CGRectMake(cellX, 0, activeWidth, cellHeight);
	CGFloat baseWidth = cellWidth + (notHeadOrTail ? 0.0f : gap);
	CGRect baseFrame = CGRectMake(cellX, 0, baseWidth, cellHeight);
	cell.activeFrame = activeFrame;
	cell.collapsedFrame = baseFrame;
	cell.baseFrame = baseFrame;
	cell.frame = cellFrame;
}

extern "C" void reloadPredictionBar()
{
	UIKeyboardPredictionView *kbView = (UIKeyboardPredictionView *)[objc_getClass("UIKeyboardPredictionView") activeInstance];
	if ([kbView isKindOfClass:objc_getClass("UIKeyboardPredictionView")]) {
		if (!kbView.show)
			return;
		NSMutableArray *cells = MSHookIvar<NSMutableArray *>(kbView, "m_predictionCells");
		if (cells.count == 0)
			return;
		for (UIKeyboardPredictionCell *cell in cells) {
			[cell removeFromSuperview];
		}
		[cells release];
		NSUInteger cellCount = [objc_getClass("UIKeyboardPredictionView") numberOfCandidates];
		cells = [[NSMutableArray alloc] initWithCapacity:cellCount];
		if (cellCount > 0) {
			NSUInteger index = 0;
			do {
				UIKeyboardPredictionCell *cell = [[objc_getClass("UIKeyboardPredictionCell") alloc] initWithFrame:CGRectZero];
				cell.label.font = [UIFont systemFontOfSize:18.0f];
				cell.opaque = NO;
				[kbView addSubview:cell];
				setCellRect(cell, kbView.frame, index, cellCount);
				[cells addObject:cell];
				index++;
			} while (index < cellCount);
		}
		MSHookIvar<NSMutableArray *>(kbView, "m_predictionCells") = cells;
	}
}

static NSUInteger landscapeCount;
static NSUInteger portraitCount;
static CGFloat predictionGap;

BOOL is_kbd;

static NSUInteger predictionCountForLandscape(BOOL landscape)
{
	return landscape ? landscapeCount : portraitCount;
}

static NSUInteger predictionCount()
{
	//UIInterfaceOrientation orientation = [[UIKeyboardImpl activeInstance] interfaceOrientation];
	UIInterfaceOrientation orientation = [[UIScreen mainScreen] _interfaceOrientation];
	BOOL isLandscape = orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight;
	return predictionCountForLandscape(isLandscape);
}

%group app

BOOL padHook;

%hook UIDevice

- (UIUserInterfaceIdiom)userInterfaceIdiom
{
	return padHook ? UIUserInterfaceIdiomPhone : %orig;
}

%end

%hook UIKeyboardImpl

- (void)textFrameChanged:(id)arg1
{
	%orig;
	if (landscapeCount != portraitCount)
		reloadPredictionBar();
}

%end

%hook UITextReplacementGeneratorForCorrections

- (void)setMaxCountAfterAutocorrectionGuesses:(NSUInteger)count
{
	%orig(predictionCount());
}

- (NSUInteger)maxCountAfterAutocorrectionGuesses
{
	return predictionCount();
}

- (void)setMaxCountAfterSpellingGuesses:(NSUInteger)count
{
	%orig(predictionCount());
}

%end

%hook UIKeyboardPredictionView

+ (CGFloat)overlapHeight
{
	return predictionGap;
}

+ (NSUInteger)numberOfCandidates
{
	return predictionCount();
}

- (NSUInteger)messageCount
{
	return predictionCount();
}

- (NSUInteger)maxMessageCount
{
	return predictionCount();
}

- (void)setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection
{
	%orig;
	self.frame = self.frame;
}

- (id)initWithFrame:(CGRect)frame
{
	padHook = YES;
	self = %orig;
	padHook = NO;
	return self;
}

- (void)setFrame:(CGRect)frame
{
	padHook = YES;
	%orig;
	padHook = NO;
	NSMutableArray *cells = MSHookIvar<NSMutableArray *>(self, "m_predictionCells");
	if (cells) {
		NSInteger state = self.state;
		if (state != 0) {
			NSUInteger cellCount = cells.count;
			if (cellCount > 0) {
				NSUInteger index = 0;
				do {
					UIKeyboardPredictionCell *cell = cells[index];
					setCellRect(cell, frame, index, cellCount);
					index++;
				} while (index < cellCount);
			}
		}
	}
}

%end

%end

%group kbd

%hook TIKeyboardInputManagerZephyr

static TIAutocorrectionList *filteredAutocorrectionList(TIKeyboardInputManagerZephyr *manager, TIAutocorrectionList *originalList)
{
	if (originalList.autocorrection == nil)
		return originalList;
	NSArray *pureAutocorrectionList = [manager completionCandidates];
	NSMutableArray *ourAutocorrectionList = [NSMutableArray array];
	[ourAutocorrectionList addObjectsFromArray:pureAutocorrectionList];
	NSUInteger predictCount = predictionCount();
	if (ourAutocorrectionList.count >= predictCount)
		[ourAutocorrectionList removeObjectsAtIndexes:[manager indexesOfDuplicatesInCandidates:ourAutocorrectionList]];
	/*if (ourAutocorrectionList.count > predictCount) {
		NSUInteger stopIndex = predictCount;
		NSUInteger startIndex = ourAutocorrectionList.count - 1;
		do {
			[ourAutocorrectionList removeObjectAtIndex:startIndex];
			startIndex--;
		} while (startIndex >= stopIndex);
	}*/
	TIZephyrCandidate *autocorrection = [manager extendedAutocorrection:[manager topCandidate] spanningInputsForCandidates:ourAutocorrectionList];
	return [TIAutocorrectionList listWithAutocorrection:autocorrection predictions:ourAutocorrectionList];
}

- (TIAutocorrectionList *)autocorrectionList
{
	TIAutocorrectionList *originalList = %orig;
	//NSLog(@"%@ %@", originalList.autocorrection, originalList.predictions);
	return filteredAutocorrectionList(self, originalList);
}

- (id)autocorrectionListForEmptyInputWithDesiredCandidateCount:(NSUInteger)count
{
	return %orig(predictionCount());
}

%end

%hook TICandidateCommitHistory

- (id)initWithMaxCommittedCandidateCount:(NSUInteger)count
{
	return %orig(predictionCount());
}

- (NSUInteger)maxCommittedCandidateCount
{
	return predictionCount();
}

- (void)setMaxCommittedCandidateCount:(NSUInteger)count
{
	%orig(predictionCount());
}

%end

%hook TIKeyboardInputManager

- (NSUInteger)maxCandidateCount
{
	return predictionCount();
}

- (void)setMaxCandidateCount:(NSUInteger)count
{
	%orig(predictionCount());
}

%end

%end

static void letsprefs()
{
	CFPreferencesAppSynchronize(domain);
	Boolean keyExist;
	NSInteger value = CFPreferencesGetAppIntegerValue(landscapeKey, domain, &keyExist);
	landscapeCount = !keyExist ? 3 : value;
	value = CFPreferencesGetAppIntegerValue(portraitKey, domain, &keyExist);
	portraitCount = !keyExist ? 3 : value;
	id gapValue = (id)CFPreferencesCopyAppValue(gapKey, domain);
	if (gapValue) {
		#ifdef __LP64__
		predictionGap = [gapValue doubleValue];
		#else
		predictionGap = [gapValue floatValue];
		#endif
	} else
		predictionGap = 1.0f;
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	letsprefs();
	if (!is_kbd)
		reloadPredictionBar();
}

%ctor
{
	NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
	NSUInteger count = args.count;
	if (count != 0) {
		NSString *executablePath = args[0];
		if (executablePath) {
			BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
			BOOL isSpringBoard = [[executablePath lastPathComponent] isEqualToString:@"SpringBoard"];
			is_kbd = [[executablePath lastPathComponent] isEqualToString:@"kbd"];
			if (is_kbd || isApplication || isSpringBoard) {
				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
				letsprefs();
			}
			if (is_kbd) {
				dlopen("/System/Library/TextInput/libTextInputCore.dylib", RTLD_LAZY);
				%init(kbd);
			}
			if (isApplication || isSpringBoard) {
				%init(app);
			}
		}
	}
}

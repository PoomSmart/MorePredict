#import "../PS.h"

CFStringRef domain = CFSTR("/var/mobile/Library/Preferences/com.PS.MorePredict");
CFStringRef PreferencesNotification = CFSTR("com.PS.MorePredict.prefs");
CFStringRef landscapeKey = CFSTR("UIPredictionCountForLandscape");
CFStringRef portraitKey = CFSTR("UIPredictionCountForPortrait");
CFStringRef gapKey = CFSTR("UIPredictionGap");

@interface UIInputSwitcherView : UIView
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

- (void)setCellsFrame:(CGRect)frame;
@end

@interface TIInputMode : NSObject {
	uint8_t NSObject_opaque[4];
	NSString *_languageWithRegion;
	NSString *_variant;
	NSLocale *_locale;
	Class _inputManagerClass;
	NSString *_normalizedIdentifier;
}
@end

@interface TIKeyboardInputManagerBase : NSObject {
	TIInputMode *_inputMode;
}
@end

@interface TIKeyboardInputManager : TIKeyboardInputManagerBase
@end

typedef struct TIInputManagerZephyr {
	TIKeyboardInputManager *manager;
} *TIInputManagerZephyrRef;

@interface TIKeyboardInputManagerZephyr : TIKeyboardInputManager {
	TIInputManagerZephyrRef m_impl;
	NSMutableString *m_composedText;
	unsigned int m_initialSelectedIndex;
	int m_typology_recorder;
	char _isEditingWordPrefix;
	char _wordLearningEnabled;
	int _config;
	int _autocorrectionHistory;
	int _rejectedAutocorrections;
	int _autocorrectionsSuggestedForCurrentInput;
	int _textCheckerExemptions;
	int _acceptableCharacterSet;
	int _revisionHistory;
	int _autoshiftRegexLoader;
}
- (NSArray *)completionCandidates;
- (NSIndexSet *)indexesOfDuplicatesInCandidates:(NSArray *)candidates;
- (TIZephyrCandidate *)topCandidate;
- (TIZephyrCandidate *)extendedAutocorrection:(TIZephyrCandidate *)autocorrection spanningInputsForCandidates:(NSArray *)candidates;
- (TIAutocorrectionList *)autocorrectionListForEmptyInputWithDesiredCandidateCount:(NSUInteger)count;
- (TIAutocorrectionList *)autocorrectionListForSelectedText;
- (BOOL)shouldGenerateSuggestionsForSelectedText;
- (NSUInteger)inputCount;
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
		[UIKeyboardImpl.activeInstance.autocorrectionController updateSuggestionViews];
	}
}

static NSUInteger landscapeCount;
static NSUInteger portraitCount;
static NSUInteger maxCount;
static CGFloat predictionGap;

BOOL is_kbd;

static NSUInteger predictionCountForLandscape(BOOL landscape)
{
	return landscape ? landscapeCount : portraitCount;
}

static NSUInteger predictionCount()
{
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

%hook UICompatibilityInputViewController

- (void)didRotateFromInterfaceOrientation:(NSInteger)orientation
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

- (void)_setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection
{
	%orig;
	[self setCellsFrame:self.frame];
}

- (id)initWithFrame:(CGRect)frame
{
	padHook = YES;
	self = %orig;
	padHook = NO;
	return self;
}

%new
- (void)setCellsFrame:(CGRect)frame
{
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

- (void)setFrame:(CGRect)frame
{
	padHook = YES;
	%orig;
	padHook = NO;
	[self setCellsFrame:frame];
}

%end

%end

%group kbd

BOOL fakeCount = NO;
BOOL markCode1 = NO;
BOOL markCode2 = YES;
int seeArrays = 0;
NSUInteger excess = 0;

%hook __NSPlaceholderArray

- (id)initWithCapacity:(NSUInteger)capacity
{
	if (fakeCount && markCode1) {
		if (capacity == 2 || capacity == 3) {
			capacity = portraitCount;
			seeArrays++;
		}
		if (seeArrays == 2)
			markCode1 = NO;
	}
	return %orig(capacity);
}

%end

%hook __NSArrayM

- (NSUInteger)count
{
	NSUInteger count = %orig;
	if (fakeCount && markCode2) {
		if (count > 2 && excess++ <= maxCount - 3) {
			return 2;
		}
		excess = 0;
	}
	return count;
}

%end

%hook TIKeyboardInputManagerZephyr

- (id)autocorrection
{
	if (fakeCount)
		markCode1 = YES;
	return %orig;
}

- (id)completionCandidates
{
	if (fakeCount)
		markCode2 = NO;
	id r = %orig;
	if (fakeCount)
		markCode2 = YES;
	return r;
}

- (id)extendedAutocorrection:(id)arg1 spanningInputsForCandidates:(id)arg2
{
	markCode2 = NO;
	return %orig;
}

- (TIAutocorrectionList *)autocorrectionList
{
	fakeCount = YES;
	TIAutocorrectionList *t1 = %orig;
	fakeCount = markCode1 = markCode2 = NO;
	return t1;
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

NSString *path = @"/var/mobile/Library/Preferences/com.PS.MorePredict.plist";

static void letsprefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
	id object1 = prefs[(NSString *)landscapeKey];
	id object2 = prefs[(NSString *)portraitKey];
	id object3 = prefs[(NSString *)gapKey];
	landscapeCount = object1 ? [object1 intValue] : 3;
	portraitCount = object2 ? [object2 intValue] : 3;
	maxCount = portraitCount;
	if (landscapeCount > maxCount)
		maxCount = landscapeCount;
	predictionGap = object3 ? [object3 doubleValue] : 1.0f;
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
				%init(kbd);
			}
			if (isApplication || isSpringBoard) {
				%init(app);
			}
		}
	}
}